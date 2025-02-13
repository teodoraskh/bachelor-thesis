import numpy as np
import time
import sys
from reductions.barrett_np import BarrettReduction

# By using numpy, we can do everything with vectorized operations
# This approach doesn't yet use NTT, as its sole purpose is to help
# me understand how much slower the operations are without it.
# Afterwards, when I have gotten the results, the NTT step will also be implemented

# Use a seed for reproducible results!!!
np.random.seed(7)

if __name__ == "__main__":
  if len(sys.argv) < 1:
    print("Please state the reduction algorithm to be tested!")
    print("Usage: python main.py <red_alg>")
    sys.exit(1)

  # Get the polynomials from a uniform distribution:
  degree = np.random.randint(2**8, 2**10)
  # print(f"degree: {degree}")
  modulus = 17

  # This needs to be changed to an if-else or smth depending on the requested algorithm
  # Or use polymorphism?
  red = BarrettReduction(modulus)
  print("Doing modular reduction with plain Barrett reduction:")

  A = np.random.randint(0, modulus, size=degree, dtype=np.int64)
  B = np.random.randint(0, modulus, size=degree, dtype=np.int64)

  n = len(A)
  m = len(B)

  C = np.zeros(n + m - 1, dtype=np.int64)

  start_time = time.perf_counter()
  for i in range(n):
    product = A[i] * B
    reduced_product = red.reduce(product) 
    # The resulting array has indeed elements lower than the modulus
    # But the sum still increases, so we need to reduce it once more
    # to keep it within the bounds of the ring
    # (simply comment out line 44 to see what the results look like wihtout it)
    C_slice = C[i:i+m] + reduced_product
    C[i:i+m] = red.reduce(C_slice)

  end_time = time.perf_counter()
  print(f"Elapsed time: {(end_time - start_time)} (ms)")
  print(f"New polynomial degree: {C.shape[0]}")
  # print(C.tolist() )