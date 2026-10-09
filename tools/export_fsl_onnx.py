"""Convert the pretrained FSL-105 SignTransformer (remi-9/fslr-transformer-vs-iv3gru)
to ONNX for in-browser inference with onnxruntime-web.

Usage: py -3.11 tools/export_fsl_onnx.py <repo_dir> <checkpoint.pt> <out_dir>
Writes: <out_dir>/fsl105_transformer.onnx, <out_dir>/fsl105_labels.json
"""
import csv
import json
import sys
from pathlib import Path

import numpy as np
import torch

repo, ckpt_path, out_dir = Path(sys.argv[1]), Path(sys.argv[2]), Path(sys.argv[3])
import importlib.util  # noqa: E402

_spec = importlib.util.spec_from_file_location("sign_transformer", repo / "models" / "transformer.py")
_mod = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_mod)
SignTransformer = _mod.SignTransformer

ckpt = torch.load(ckpt_path, map_location="cpu", weights_only=False)
sd = ckpt.get("model_state_dict", ckpt.get("state_dict", ckpt.get("model", ckpt)))
cfg = {k: ckpt.get(k) for k in ("config", "args", "hparams") if isinstance(ckpt, dict) and k in ckpt}
print("checkpoint keys:", list(ckpt.keys())[:10] if isinstance(ckpt, dict) else type(ckpt))
print("config-ish:", {k: (v if not hasattr(v, "keys") else dict(list(v.items())[:20])) for k, v in cfg.items()})

emb_dim = sd["embedding.weight"].shape[0]
n_layers = len({k.split(".")[1] for k in sd if k.startswith("encoder_layers.")})
num_gloss = sd["gloss_head.3.weight"].shape[0]
num_cat = sd["category_head.3.weight"].shape[0]
ff_keys = [k for k in sd if k.startswith("encoder_layers.0.") and "weight" in k and sd[k].ndim == 2]
ff_dim = max(sd[k].shape[0] for k in ff_keys)
print(f"emb_dim={emb_dim} n_layers={n_layers} ff_dim={ff_dim} gloss={num_gloss} cat={num_cat}")


class Wrapper(torch.nn.Module):
    """Single input [1,T,178] -> (gloss_probs, cat_probs)."""

    def __init__(self, m):
        super().__init__()
        self.m = m

    def forward(self, x):
        g, c = self.m(x)
        return torch.softmax(g, -1), torch.softmax(c, -1)


def build(pooling):
    m = SignTransformer(input_dim=178, emb_dim=emb_dim, n_heads=8, n_layers=n_layers,
                        num_gloss=num_gloss, num_cat=num_cat, ff_dim=ff_dim,
                        pooling_method=pooling)
    m.load_state_dict(sd)
    return m.eval()


pooling = "mean"
for p in ("mean", "max", "cls"):
    try:
        build(p)
        pooling = p if isinstance(ckpt, dict) and str(cfg).find(p) >= 0 else pooling
    except Exception as e:  # noqa: BLE001
        print("pooling", p, "failed:", e)
model = Wrapper(build(pooling)).eval()
print("pooling:", pooling)

out_dir.mkdir(parents=True, exist_ok=True)
onnx_path = out_dir / "fsl105_transformer.onnx"
dummy = torch.rand(1, 60, 178)
torch.onnx.export(model, (dummy,), str(onnx_path), input_names=["x"],
                  output_names=["gloss_probs", "cat_probs"],
                  dynamic_axes={"x": {1: "T"}}, opset_version=17, dynamo=False)

import onnxruntime as ort  # noqa: E402

model.eval()  # torch.onnx.export restores the previous (train) mode
sess = ort.InferenceSession(str(onnx_path))
for T in (30, 75, 140):
    x = torch.rand(1, T, 178)
    with torch.no_grad():
        ref = model(x)[0].numpy()
    got = sess.run(None, {"x": x.numpy()})[0]
    print(f"T={T} max|torch-onnx| = {np.abs(ref - got).max():.2e}")

labels = []
with open(repo / "data" / "labels_reference.csv", encoding="utf-8") as f:
    for row in csv.DictReader(f):
        labels.append({"id": int(row["gloss_id"]), "gloss": row["label"].strip(),
                       "cat": row["category"].strip()})
(out_dir / "fsl105_labels.json").write_text(json.dumps(labels, ensure_ascii=False, indent=0),
                                            encoding="utf-8")
print("wrote", onnx_path, onnx_path.stat().st_size // 1024, "KB and labels", len(labels))
