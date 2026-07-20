import numpy as np

data = np.load('weights/mnist_mlp_128.npz')
w1 = data['w1']   # (784, 128) float32

# 255 weights + 1 zero slot = 256 words, matching DEPTH
flat = w1.flatten()[:255]
print("taking", len(flat), "weights")

# quantize float -> int8
scale = 127.0 / np.max(np.abs(w1))
q = np.round(flat * scale).astype(np.int8)

# convert to unsigned 8-bit hex (two's complement for negatives)
hex_values = [format(int(v) & 0xFF, '02x') for v in q]

# write the .hex file, zero slot at mem[0], weights in mem[1..255]
with open('weights.hex', 'w') as f:
    f.write('00\n')              # mem[0] = 0, read during idle cycles
    for h in hex_values:
        f.write(h + '\n')
print("wrote weights.hex with", len(hex_values) + 1, "values")