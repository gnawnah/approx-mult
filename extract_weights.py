import numpy as np

data = np.load('weights/mnist_mlp_128.npz')
w1 = data['w1']   # (784, 128) float32

# take a bigger slice: the first 256 weights (flattened) — enough to infer a BRAM
flat = w1.flatten()[:256]
print("taking", len(flat), "weights")

# quantize float -> int8
scale = 127.0 / np.max(np.abs(w1))
q = np.round(flat * scale).astype(np.int8)

# convert to unsigned 8-bit hex (two's complement for negatives)
hex_values = [format(int(v) & 0xFF, '02x') for v in q]

# write the .hex file
with open('weights.hex', 'w') as f:
    for h in hex_values:
        f.write(h + '\n')
print("wrote weights.hex with", len(hex_values), "values")