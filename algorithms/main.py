import numpy as np
import random
import time
import sys
from reductions.modred import ALGORITHMS

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

  for _ in range(0, 1):
    # Get the polynomials from a uniform distribution:
    degree = np.random.randint(2**8, 2**10)
    # degree = 256
    # modulus = np.random.randint(2, (1 << 63) - 1) | 1
    # kyber modulus
    # modulus = 3329
    # dilithium modulus
    modulus = 8380417

    # Polynomial coefficients between 0 and the modulus
    A = np.random.randint(0, modulus, size=degree, dtype=np.uint64)
    B = np.random.randint(0, modulus, size=degree, dtype=np.uint64)

    n = len(A)
    m = len(B)

    conv = np.zeros(n + m - 1, dtype=np.object_)

    results = {}

    # Get the reduction instance:
    for algorithm in algorithms_to_test:
      C = np.zeros(n + m - 1, dtype=np.object_)
      reduction_instance = ALGORITHMS[algorithm](modulus)
      print("------------------------------------------------------------------------")
      print(f"Algorithm: {algorithm}")
      print(f"Modulus:   {modulus}")
      start_time = time.perf_counter()
      if algorithm == "montgomery":
        conv = A * reduction_instance.to_montgomery(B)
      else:
        conv = A * B

      print("conv:", np.vectorize(hex)(conv))
      C = reduction_instance.reduce(conv)
      results[algorithm] = C

      end_time = time.perf_counter()
      print(f"Elapsed time: {(end_time - start_time) * 1000} (ms)")
      print(f"New polynomial degree: {C.shape[0]}")
      print(np.vectorize(hex)(C))

    reference_key, reference_value = next(iter(results.items()))
    mismatched_keys = [key for key, value in results.items() if not np.array_equal(value, reference_value)]
    if mismatched_keys:
        print(f"Mismatched keys: {mismatched_keys}")
        assert False, f"Not all results are the same! Mismatched keys: {mismatched_keys}"

    print("Reduction successfully done!")
