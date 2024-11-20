# Barrett Reduction
import math

modulus = 17
k = 5

def barrett(a, b):
  print("\n\n\n")
  mult = int(a, 2) * int(b,2)
  mu = math.floor((2 ** (2*k)) / modulus)
  approximated_quotient = math.floor((mult * mu) / (2 ** (2*k)))
  remainder = mult - approximated_quotient * modulus
  print(remainder)
  if remainder >= modulus:
    return remainder - modulus
  return remainder


def main():
    binary_pairs = [] 
    with open("addshift.txt", "r") as file:
        for line in file:
            binary_pairs.append(line.strip().split())

    for (a, b) in binary_pairs:
      print(bin(barrett(a, b)))
           


if __name__ == "__main__":
    main()
