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
    print("Please state the reduction algorithm(s) to be tested!")
    print("Usage: python main.py <red_alg>, ")
    print("Where <red_alg> = all | montgomery | barrett | shiftadd")
    sys.exit(1)

  # Get the algorithm name requested by the user:
  # algorithm_name = sys.argv[1].lower()
  algorithms_to_test = []
  if sys.argv[1].lower() == "all":
    algorithms_to_test = ALGORITHMS
  else:
    in_vals = [s.lower() for s in sys.argv[1:]]
    algorithms_to_test.append("schoolbook")
    algorithms_to_test += in_vals

  # Get the polynomials from a uniform distribution:
  degree = np.random.randint(2**8, 2**10)
  
  # modulus = 7069
  # modulus = 17
  modulus = np.random.randint(2, (1 << 63) - 1)

  # Polynomial coefficients between 0 and the modulus
  A = np.random.randint(0, modulus, size=degree, dtype=np.uint64)
  B = np.random.randint(0, modulus, size=degree, dtype=np.uint64)

  n = len(A)
  m = len(B)

  conv = np.zeros(n + m - 1, dtype=np.object_)

  results = []

  # Get the reduction instance:
  for algorithm in algorithms_to_test:
    C = np.zeros(n + m - 1, dtype=np.object_)
    reduction_instance = ALGORITHMS[algorithm](modulus)
    print("------------------------------------------------------------------------")
    print(f"Algorithm: {algorithm}")
    print(f"Modulus:   {modulus}")
    start_time = time.perf_counter()
    if algorithm == "montgomery":
      conv = reduction_instance.to_montgomery(np.convolve(A, B))
    else:
      conv = np.convolve(A, B)

    # the polynomial reduction by x^n + 1 is missing as well for now.
    # use np.convolve(A, B) instead of A * B which is element-wise multiplication
    C = reduction_instance.reduce(conv) 
    results.append(C)
    if algorithm == "montgomery":
      C = reduction_instance.from_montgomery(C)


    end_time = time.perf_counter()
    print(f"Elapsed time: {(end_time - start_time) * 1000} (ms)")
    print(f"New polynomial degree: {C.shape[0]}")
    print(C[25])

  assert all(np.array_equal(result, results[0]) for result in results), "Not all results are the same!"

  print("Reduction successfully done!")