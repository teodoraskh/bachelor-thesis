# Barrett Reduction
import math
import time

modulus = 17
k = modulus.bit_length()

def barrett(a, b):
  start_time = time.perf_counter()
  mult = int(a, 2) * int(b,2)
  mu = math.floor((2 ** (2*k)) / modulus)
  approximated_quotient = math.floor((mult * mu) / (2 ** (2*k)))
  remainder = mult - approximated_quotient * modulus
  while remainder >= modulus:
    remainder -= modulus
  end_time = time.perf_counter()
  print(remainder)
  return remainder, end_time - start_time


def main():
    binary_pairs = [] 
    with open("addshift.txt", "r") as file:
        for line in file:
            binary_pairs.append(line.strip().split())

    print("Doing modular reduction with plain Barrett reduction:")
    for (a, b) in binary_pairs:
      print("-------------------------------------------------")
      res, elapsed_time = barrett(a, b)
      print(f"Compute {int(a, 2)} * {int(b, 2)} % {modulus} = {res} ({bin(res)})")
      print(f"elapsed time: {elapsed_time * 1000} (ms)")
           

if __name__ == "__main__":
    main()
