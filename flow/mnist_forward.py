#!/usr/bin/env python3
import argparse
from pathlib import Path

import numpy as np

# this script does the network work and establishes the base line ~ 97.73%

def load_mnist(path):
    data = np.load(path)
    x_test = data["x_test"].reshape(-1, 784).astype(np.float32) / 255.0
    y_test = data["y_test"].astype(np.int64)
    return x_test, y_test


def forward(x, weights):
    hidden = np.maximum(x @ weights["w1"] + weights["b1"], 0.0)
    logits = hidden @ weights["w2"] + weights["b2"]
    return np.argmax(logits, axis=1)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--mnist", default="data/mnist.npz")
    parser.add_argument("--weights", default="weights/mnist_mlp_128.npz")
    args = parser.parse_args()

    mnist_path = Path(args.mnist)
    weights_path = Path(args.weights)
    if not mnist_path.exists():
        raise SystemExit(f"Missing {mnist_path}.")
    if not weights_path.exists():
        raise SystemExit(
            f"Missing {weights_path}. Run train_mnist_weights.py first."
        )

    x_test, y_test = load_mnist(mnist_path)
    weights = np.load(weights_path)
    pred = forward(x_test, weights)
    accuracy = np.mean(pred == y_test)

    print(f"accuracy={accuracy:.4f}")


if __name__ == "__main__":
    main()
