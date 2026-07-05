import numpy as np

data = np.load('weights/mnist_mlp_128.npz')
w1 = data['w1']   # (784, 128) float32

# --- take a small slice (a 2x2 block, to match your 2x2 array) ---
block = w1[:2, :2]
print("raw 2x2 float block:\n", block)

# --- quantize float -> int8 ---
# scale so the largest-magnitude weight maps to ~127
scale = 127.0 / np.max(np.abs(w1))
block_q = np.round(block * scale).astype(np.int8)
print("quantized int8 block:\n", block_q)

# --- convert each int8 to its unsigned 8-bit hex pattern (two's complement) ---
# (& 0xFF turns a negative int8 like -5 into 0xFB, the raw byte the memory stores)
hex_values = [format(int(v) & 0xFF, '02x') for v in block_q.flatten()]
print("hex (row-major):", hex_values)

# --- write the .hex file that $readmemh will load ---
# write the .hex file WITH the zero slot at address 0
with open('weights.hex', 'w') as f:
    f.write('00\n')          # mem[0] = 0 (zero slot for idle reads)
    for h in hex_values:     # mem[1..4] = the real weights
        f.write(h + '\n')
print("wrote weights.hex with zero slot")