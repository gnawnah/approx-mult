#!/usr/bin/env python3
import argparse
import csv
from pathlib import Path

import numpy as np


def load_mnist(path):
    data = np.load(path)
    x_train = data["x_train"].reshape(-1, 784).astype(np.float32) / 255.0
    x_test = data["x_test"].reshape(-1, 784).astype(np.float32) / 255.0
    y_test = data["y_test"].astype(np.int64)
    return x_train, x_test, y_test


def quantize_symmetric(x, bits=8):
    qmax = (1 << (bits - 1)) - 1
    scale = np.max(np.abs(x)) / qmax
    if scale == 0.0:
        scale = 1.0
    q = np.round(x / scale).clip(-qmax, qmax).astype(np.int16)
    return q, scale


def quantize_unsigned(x, scale):
    return np.round(x / scale).clip(0, 255).astype(np.uint8)


def trunc_unsigned(x, trunc_bits):        # activations
    if trunc_bits == 0:
        return x.astype(np.int32)
    x = x.astype(np.int32)
    return (x >> trunc_bits) << trunc_bits


def trunc_signed(x, trunc_bits):          # weights
    if trunc_bits == 0:
        return x.astype(np.int32)
    x = x.astype(np.int32)
    sign = np.where(x < 0, -1, 1)
    mag = np.abs(x)
    return sign * ((mag >> trunc_bits) << trunc_bits)


def mean_multiply_error(x, w, trunc_bits):
    if trunc_bits == 0:
        return 0.0
    x_t = trunc_unsigned(x, trunc_bits).astype(np.float64)
    w_t = trunc_signed(w, trunc_bits).astype(np.float64)
    da = x.astype(np.float64) - x_t        # dropped part of activation
    db = w.astype(np.float64) - w_t        # dropped part of weight
    # expected per-multiply error, averaged over all operands in this layer
    return x_t.mean() * db.mean() + w_t.mean() * da.mean() + da.mean() * db.mean()


def linear_u8_s8(x_u8, w_i8, trunc_bits=0, correct=False):
    x_t = trunc_unsigned(x_u8, trunc_bits)
    w_t = trunc_signed(w_i8, trunc_bits)
    out = x_t @ w_t
    if correct and trunc_bits > 0:
        c = mean_multiply_error(x_u8, w_i8, trunc_bits)
        k = x_t.shape[1]                 
        out = out + int(round(c * k))
    return out


def calibrate_hidden_scale(x_train, weights):
    hidden = np.maximum(x_train @ weights["w1"] + weights["b1"], 0.0)
    max_hidden = np.max(hidden)
    if max_hidden == 0.0:
        return 1.0
    return max_hidden / 255.0


def run_inference(x_test, y_test, weights, trunc_bits, hidden_scale, correct=False):
    input_scale = 1.0 / 255.0
    x_u8 = quantize_unsigned(x_test, input_scale)
    w1_i8, w1_scale = quantize_symmetric(weights["w1"])
    w2_i8, w2_scale = quantize_symmetric(weights["w2"])

    z1_int = linear_u8_s8(x_u8, w1_i8, trunc_bits, correct)
    z1 = z1_int.astype(np.float32) * input_scale * w1_scale + weights["b1"]
    a1 = np.maximum(z1, 0.0)
    a1_u8 = quantize_unsigned(a1, hidden_scale)

    z2_int = linear_u8_s8(a1_u8, w2_i8, trunc_bits, correct)
    logits = z2_int.astype(np.float32) * hidden_scale * w2_scale + weights["b2"]
    pred = np.argmax(logits, axis=1)
    return np.mean(pred == y_test)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--mnist", default="data/mnist.npz")
    parser.add_argument("--weights", default="weights/mnist_mlp_128.npz")
    parser.add_argument("--out", default="results/mnist_corrected_results.csv")
    args = parser.parse_args()

    mnist_path = Path(args.mnist)
    weights_path = Path(args.weights)
    if not mnist_path.exists():
        raise SystemExit(f"Missing {mnist_path}.")
    if not weights_path.exists():
        raise SystemExit(f"Missing {weights_path}. Run train_mnist_weights.py first.")

    x_train, x_test, y_test = load_mnist(mnist_path)
    weights = np.load(weights_path)
    hidden_scale = calibrate_hidden_scale(x_train, weights)

    rows = []
    for trunc_bits in range(8):
        acc_plain     = run_inference(x_test, y_test, weights, trunc_bits, hidden_scale, correct=False)
        acc_corrected = run_inference(x_test, y_test, weights, trunc_bits, hidden_scale, correct=True)
        rows.append({
            "trunc_bits": trunc_bits,
            "accuracy_plain": acc_plain,
            "accuracy_corrected": acc_corrected,
        })
        print(f"T={trunc_bits}: plain={acc_plain:.4f}  corrected={acc_corrected:.4f}")

    with open(args.out, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=["trunc_bits", "accuracy_plain", "accuracy_corrected"])
        writer.writeheader()
        writer.writerows(rows)

    print(f"saved {args.out}")


if __name__ == "__main__":
    main()