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
  
  modulus = 7069
  # modulus = 19
  # Get the reduction instance:
  reduction_instance = ALGORITHMS[algorithm_name](modulus)

  print(f"Doing modular reduction with: {algorithm_name} and modulus: {modulus}")

  # Polynomial coefficients between 0 and the modulus
  A = np.random.randint(0, modulus, size=degree, dtype=np.int64)
  B = np.random.randint(0, modulus, size=degree, dtype=np.int64)

  n = len(A)
  m = len(B)

  C = np.zeros(n + m - 1, dtype=np.int64)

  if algorithm_name == "montgomery":
    A = reduction_instance.to_montgomery(A)
    B = reduction_instance.to_montgomery(B)

  start_time = time.perf_counter()
  # for i in range(n):
  #   product = A[i] * B
  C = reduction_instance.reduce(A * B) 

  end_time = time.perf_counter()
  print(f"Elapsed time: {(end_time - start_time) * 1000} (ms)")
  if algorithm_name == "montgomery":
    C = reduction_instance.from_montgomery(C)
  print(f"New polynomial degree: {C.shape[0]}")
  print(C)