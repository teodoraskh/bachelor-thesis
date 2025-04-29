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

  for _ in range(0, 1):
    # Get the polynomials from a uniform distribution:
    degree = np.random.randint(2**8, 2**10)
    
    # modulus = 2450863333

    # modulus = 7069
    # modulus = 17

    # force nodulus to be odd?
    # similar approach here: https://www.nayuki.io/res/montgomery-reduction-algorithm/montgomery-reducer.py
    modulus = np.random.randint(2, (1 << 63) - 1) | 1  
    # these VVV aren't
    # modulus = np.random.randint(2, (1 << 32) - 1) | 1
    # modulus = 7
    # this is montgomery friendly
    # modulus = (1 << 62) - 1

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
        # A_m = reduction_instance.to_montgomery(A)
        # B_m = reduction_instance.to_montgomery(B)
        # print(A_m)
        # print(B_m)

        # this VVVV will of course not work because convolution will make the
        # coefficients larger than modulus^2 - and this input should be avoided 
        # for barrett reduction, where 0 <= input < modulus^2
        # conv = reduction_instance.to_montgomery(np.convolve(A, B))

        # if we were to use NTT, then this convolution would become element-wise
        # multiplication, which ensures the fact that:
        # 1. the polynomial degrees do not exceed *n*
        # 2. polymul in NTT form is now element-wise multiplication instead of convolution,
        #    which ensures the fact that the result of the multiplied coefficients will not
        #    exceed modulus^2.
        # therefore, for the sake of simplicity, we'll just use element-wise multiplication,
        # which will now fit the algorithms
        # conv = reduction_instance.to_montgomery(A) * reduction_instance.to_montgomery(B)
        print("not mont: ", np.vectorize(hex)(A*B))
        conv = reduction_instance.to_montgomery(A*B)
        # conv = np.convolve(A_m, B_m)
      else:
        conv = A * B

        # print(A)
        # print(B)

      print("conv:", np.vectorize(hex)(conv))
      # print("conv:", conv)

      # the polynomial reduction by x^n + 1 is missing as well for now.
      # use np.convolve(A, B) instead of A * B which is element-wise multiplication
      C = reduction_instance.reduce(conv) 
      # if algorithm == "montgomery":
      #   C = reduction_instance.reduce(C)

      results[algorithm] = C

      end_time = time.perf_counter()
      print(f"Elapsed time: {(end_time - start_time) * 1000} (ms)")
      print(f"New polynomial degree: {C.shape[0]}")
      print(np.vectorize(hex)(C))
      # print(C)
      # print(C[60])

    reference_key, reference_value = next(iter(results.items()))
    mismatched_keys = [key for key, value in results.items() if not np.array_equal(value, reference_value)]
    if mismatched_keys:
        print(f"Mismatched keys: {mismatched_keys}")
        assert False, f"Not all results are the same! Mismatched keys: {mismatched_keys}"

    print("Reduction successfully done!")
