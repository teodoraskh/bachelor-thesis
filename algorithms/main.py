import numpy as np
import random
import time
import sys
from reductions.modred import ALGORITHMS

# By using numpy, we can do everything with vectorized operations
# This approach doesn't yet use NTT, as its sole purpose is to help
# me understand how much slower the operations are without it.
# Afterwards, when I have gotten the results, the NTT step will also be implemented

# Use a seed for reproducible results!!!
np.random.seed(7)

if __name__ == "__main__":
  if len(sys.argv) < 2:
    print("Please state the reduction algorithm to be tested!")
    print("Usage: python main.py <red_alg>")
    sys.exit(1)

  # Get the algorithm name requested by the user:
  algorithm_name = sys.argv[1].lower()

  # Get the polynomials from a uniform distribution:
  degree = np.random.randint(2**8, 2**10)
  
  # modulus = 7069
  # modulus = 17
  modulus = (1 << 63) - 1
  # Get the reduction instance:
  reduction_instance = ALGORITHMS[algorithm_name](modulus)

  print(f"Doing modular reduction with: {algorithm_name} and modulus: {modulus}")

  # Polynomial coefficients between 0 and the modulus
  A = np.random.randint(0, modulus, size=degree, dtype=np.uint64)
  B = np.random.randint(0, modulus, size=degree, dtype=np.uint64)

  # A = np.array([1, 2, 3])
  # B = np.array([4, 5, 6])

  n = len(A)
  m = len(B)

  C = np.zeros(n + m - 1, dtype=np.object_)
  conv = np.zeros(n + m - 1, dtype=np.object_)

  start_time = time.perf_counter()

  # for algorithm in ALGORITHMS:
  if algorithm_name == "montgomery":
    conv = reduction_instance.to_montgomery(np.convolve(A, B))
  else:
    conv = np.convolve(A, B)

  # the polynomial reduction by x^n + 1 is missing as well for now.
  # use np.convolve(A, B) instead of A * B which is element-wise multiplication
  C = reduction_instance.reduce(conv) 

  end_time = time.perf_counter()
  print(f"Elapsed time: {(end_time - start_time) * 1000} (ms)")
  if algorithm_name == "montgomery":
    C = reduction_instance.from_montgomery(C)
  print(f"New polynomial degree: {C.shape[0]}")
  print(C.dtype)
  print(C)
  # print(hash(C.tobytes()))