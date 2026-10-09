"""Validate the FSL-105 ONNX recognizer end-to-end on held-out FSL-105 test clips,
using MediaPipe *Tasks* HolisticLandmarker (the same extractor the browser uses)
and the same 178-D feature construction implemented in web/fsl_recognizer.js.

Usage: py -3.11 tools/validate_fsl.py <clips.zip> <test.csv> <web_dir> [n_clips]
"""
import csv
import json
import random
import sys
import tempfile
import zipfile
from pathlib import Path

import cv2
import mediapipe as mp
import numpy as np
import onnxruntime as ort

POSE_UPPER_25 = list(range(25))
FACE_MINIMAL_22 = [81, 13, 311, 61, 178, 14, 402, 291, 33, 133, 159, 362, 263, 386,
                   70, 107, 46, 300, 336, 276, 1, 4]
CONF = 0.35
import os
SWAP = os.environ.get("SWAP") == "1"
PAD = os.environ.get("PAD") == "1"
LOWCONF = os.environ.get("LOWCONF") == "1"


def letterbox(x, y, w, h):
    """Map normalized coords on a w×h frame to a centered square canvas (training used 256² pad)."""
    s = max(w, h)
    return (x * w + (s - w) / 2) / s, (y * h + (s - h) / 2) / s


def frame_vec(res, w, h):
    vec = np.zeros(178, np.float32)
    mask = np.zeros(89, bool)
    k = 0

    def put(lms, idxs, use_vis):
        nonlocal k
        for i in idxs:
            if lms is not None and i < len(lms):
                lm = lms[i]
                ok = (getattr(lm, "visibility", 1.0) or 0.0) >= CONF if use_vis else True
                if ok:
                    vec[2 * k], vec[2 * k + 1] = letterbox(lm.x, lm.y, w, h)
                    mask[k] = True
            k += 1

    put(res.pose_landmarks or None, POSE_UPPER_25, True)
    lh, rh = res.left_hand_landmarks or None, res.right_hand_landmarks or None
    if SWAP:
        lh, rh = rh, lh
    put(lh, range(21), False)
    put(rh, range(21), False)
    put(res.face_landmarks or None, FACE_MINIMAL_22, False)
    return vec, mask


def interpolate_gaps(X, M, max_gap=5):
    X, M = X.copy(), M.copy()
    for k in range(M.shape[1]):
        v = np.where(M[:, k])[0]
        for a, b in zip(v[:-1], v[1:]):
            gap = b - a - 1
            if 1 <= gap <= max_gap:
                for j in range(1, gap + 1):
                    t = j / (gap + 1)
                    X[a + j, 2 * k:2 * k + 2] = (1 - t) * X[a, 2 * k:2 * k + 2] + t * X[b, 2 * k:2 * k + 2]
                    M[a + j, k] = True
    return np.clip(X, 0, 1), M


def extract(video_path, landmarker):
    cap = cv2.VideoCapture(str(video_path))
    fps = cap.get(cv2.CAP_PROP_FPS) or 30.0
    next_t, frames, masks = 0.0, [], []
    while True:
        ok, bgr = cap.read()
        if not ok:
            break
        ms = cap.get(cv2.CAP_PROP_POS_MSEC)
        if ms < next_t * 1000:
            continue
        h, w = bgr.shape[:2]
        if PAD:  # replicate training: resize longest side to 256, pad to 256x256
            sc = 256 / max(w, h)
            nw, nh = int(round(w * sc)), int(round(h * sc))
            canvas = np.zeros((256, 256, 3), np.uint8)
            y0, x0 = (256 - nh) // 2, (256 - nw) // 2
            canvas[y0:y0 + nh, x0:x0 + nw] = cv2.resize(bgr, (nw, nh), interpolation=cv2.INTER_AREA)
            bgr, w, h = canvas, 256, 256
        img = mp.Image(image_format=mp.ImageFormat.SRGB, data=cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB))
        res = landmarker.detect_for_video(img, int(ms))
        v, m = frame_vec(res, w, h)
        frames.append(v)
        masks.append(m)
        next_t += 1 / 30
    cap.release()
    X, _ = interpolate_gaps(np.stack(frames), np.stack(masks))
    return X, fps


def norm(s):
    return s.upper().replace("’", "'").strip()


def main():
    zpath, test_csv, web = Path(sys.argv[1]), Path(sys.argv[2]), Path(sys.argv[3])
    n = int(sys.argv[4]) if len(sys.argv) > 4 else 40
    labels = json.loads((web / "models" / "fsl105_labels.json").read_text(encoding="utf-8"))
    name_to_id = {norm(l["gloss"]): l["id"] for l in labels}
    rows = list(csv.DictReader(open(test_csv, encoding="utf-8")))
    random.Random(0).shuffle(rows)
    rows = rows[:n]
    sess = ort.InferenceSession(str(web / "models" / "fsl105_transformer.onnx"))
    opts = mp.tasks.vision.HolisticLandmarkerOptions(
        base_options=mp.tasks.BaseOptions(model_asset_path=str(web / "vendor" / "holistic_landmarker.task")),
        running_mode=mp.tasks.vision.RunningMode.VIDEO,
        **({"min_pose_detection_confidence": 0.35, "min_pose_landmarks_confidence": 0.35,
            "min_hand_landmarks_confidence": 0.35, "min_face_detection_confidence": 0.35,
            "min_face_landmarks_confidence": 0.35} if LOWCONF else {}))
    z = zipfile.ZipFile(zpath)
    names = {n.replace("\\", "/").lower(): n for n in z.namelist()}
    top1 = top5 = done = 0
    with tempfile.TemporaryDirectory() as td:
        for r in rows:
            key = r["vid_path"].replace("\\", "/").lower()
            zn = next((names[k] for k in names if k.endswith(key)), None)
            if zn is None:
                print("missing in zip:", r["vid_path"])
                continue
            p = Path(td) / Path(zn).name
            p.write_bytes(z.read(zn))
            with mp.tasks.vision.HolisticLandmarker.create_from_options(opts) as lmk:
                X, _ = extract(p, lmk)
            probs = sess.run(None, {"x": X[None].astype(np.float32)})[0][0]
            order = np.argsort(-probs)
            truth = name_to_id.get(norm(r["label"]))
            hit1, hit5 = order[0] == truth, truth in order[:5]
            top1 += hit1
            top5 += hit5
            done += 1
            print(f"{'OK ' if hit1 else 'MISS'} {r['label']:<18} -> {labels[order[0]]['gloss']:<18} "
                  f"p={probs[order[0]]:.2f} T={len(X)}")
    print(f"\nclips={done} top1={top1 / done:.1%} top5={top5 / done:.1%}")


if __name__ == "__main__":
    main()
