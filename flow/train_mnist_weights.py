#!/usr/bin/env python3
import argparse
from pathlib import Path

import numpy as np


def load_mnist(path):
    data = np.load(path)
    x_train = data["x_train"].reshape(-1, 784).astype(np.float32) / 255.0
    y_train = data["y_train"].astype(np.int64)
    return x_train, y_train


def one_hot(y, classes=10):
    out = np.zeros((y.size, classes), dtype=np.float32)
    out[np.arange(y.size), y] = 1.0
    return out


def softmax(logits):
    shifted = logits - np.max(logits, axis=1, keepdims=True)
    exp = np.exp(shifted)
    return exp / np.sum(exp, axis=1, keepdims=True)


def adam_step(params, grads, m, v, t, lr, beta1=0.9, beta2=0.999, eps=1e-8):
    for name in params:
        m[name] = beta1 * m[name] + (1.0 - beta1) * grads[name]
        v[name] = beta2 * v[name] + (1.0 - beta2) * (grads[name] * grads[name])
        m_hat = m[name] / (1.0 - beta1 ** t)
        v_hat = v[name] / (1.0 - beta2 ** t)
        params[name] -= lr * m_hat / (np.sqrt(v_hat) + eps)


def train(x_train, y_train, hidden=128, epochs=12, batch_size=128, lr=0.001):
    rng = np.random.default_rng(1)
    params = {
        "w1": rng.normal(0.0, np.sqrt(2.0 / 784), size=(784, hidden)).astype(np.float32),
        "b1": np.zeros(hidden, dtype=np.float32),
        "w2": rng.normal(0.0, np.sqrt(2.0 / hidden), size=(hidden, 10)).astype(np.float32),
        "b2": np.zeros(10, dtype=np.float32),
    }
    m = {name: np.zeros_like(value) for name, value in params.items()}
    v = {name: np.zeros_like(value) for name, value in params.items()}
    y_oh = one_hot(y_train)
    n = x_train.shape[0]
    step = 0

    for epoch in range(epochs):
        order = rng.permutation(n)
        correct = 0
        total_loss = 0.0

        for start in range(0, n, batch_size):
            step += 1
            idx = order[start:start + batch_size]
            x = x_train[idx]
            y = y_oh[idx]

            z1 = x @ params["w1"] + params["b1"]
            a1 = np.maximum(z1, 0.0)
            logits = a1 @ params["w2"] + params["b2"]
            probs = softmax(logits)

            total_loss += -np.sum(y * np.log(probs + 1e-9))
            correct += np.sum(np.argmax(probs, axis=1) == y_train[idx])

            dlogits = (probs - y) / x.shape[0]
            grads = {}
            grads["w2"] = a1.T @ dlogits
            grads["b2"] = np.sum(dlogits, axis=0)
            da1 = dlogits @ params["w2"].T
            dz1 = da1 * (z1 > 0.0)
            grads["w1"] = x.T @ dz1
            grads["b1"] = np.sum(dz1, axis=0)

            adam_step(params, grads, m, v, step, lr)

        print(
            f"epoch {epoch + 1}: "
            f"train_loss={total_loss / n:.4f}, train_acc={correct / n:.4f}"
        )

    return params


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--mnist", default="data/mnist.npz")
    parser.add_argument("--out", default="weights/mnist_mlp_128.npz")
    parser.add_argument("--hidden", type=int, default=128)
    parser.add_argument("--epochs", type=int, default=12)
    parser.add_argument("--batch-size", type=int, default=128)
    parser.add_argument("--lr", type=float, default=0.001)
    args = parser.parse_args()

    mnist_path = Path(args.mnist)
    if not mnist_path.exists():
        raise SystemExit(f"Missing {mnist_path}. Run the dataset download first.")

    x_train, y_train = load_mnist(mnist_path)
    params = train(
        x_train,
        y_train,
        hidden=args.hidden,
        epochs=args.epochs,
        batch_size=args.batch_size,
        lr=args.lr,
    )

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    np.savez(out, **params)
    print(f"saved {out}")


if __name__ == "__main__":
    main()
