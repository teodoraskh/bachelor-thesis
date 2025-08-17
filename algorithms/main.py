import numpy as np
import random
import time
import sys
from reductions.modred import ALGORITHMS

# Use a seed for reproducible results!!!
np.random.seed(7)

if __name__ == "__main__":
  if len(sys.argv) < 3:
    print("Please state the reduction algorithm(s) to be tested!")
    print("Usage: python main.py <red_alg> <modulus_decimal>")
    print("Where <red_alg> = all | montgomery | barrett | shiftadd")
    print("And   <modulus> = kyber | dilithium | other modulus (int)")

    sys.exit(1)

  # Get the algorithm name requested by the user:
  moduli = {"kyber": 3329, "dilithium": 8380417}
  modulus = 1
  algorithms_to_test = []
  if sys.argv[1].lower() == "all":
    algorithms_to_test = ALGORITHMS
  else:
    in_vals = [s.lower() for s in sys.argv[1:-2]]
    algorithms_to_test.append("schoolbook")
    algorithms_to_test += in_vals

  if sys.argv[-1] in moduli:
      modulus = moduli[sys.argv[-1]]
  else:
    try:
      n = int(sys.argv[-1])
      modulus = n
      print(f"Using custom modulus: {n}")
    except ValueError:
      print("Modulus is not part of the known moduli!")
      sys.exit(1)


  for _ in range(0, 1):
    # Get the polynomials from a uniform distribution:
    degree = np.random.randint(2**8, 2**10)

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

      # print("conv:", np.vectorize(hex)(conv))
      C = reduction_instance.reduce(conv)
      results[algorithm] = C

      end_time = time.perf_counter()
      print(f"Elapsed time: {(end_time - start_time) * 1000} (ms)")
      print(f"Reduction result: ")
      print(np.vectorize(hex)(C))

    reference_key, reference_value = next(iter(results.items()))
    mismatched_keys = [key for key, value in results.items() if not np.array_equal(value, reference_value)]
    if mismatched_keys:
        print(f"Mismatched keys: {mismatched_keys}")
        assert False, f"Not all results are the same! Mismatched keys: {mismatched_keys}"

    print("Reduction successfully done!")
