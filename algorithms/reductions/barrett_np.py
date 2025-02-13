import numpy as np

class BarrettReduction():
  def __init__(self, modulus):
    self.modulus = modulus
    self.k = self.modulus.bit_length()
    self.mu = (1 << (2 * self.k)) // modulus

  def reduce(self, mult):
    approximated_quotient = (mult * self.mu) >> (2 * self.k)
    remainder = mult - approximated_quotient * self.modulus

    # for i in range(len(remainder)):
    #   if remainder[i] >= self.modulus:
    #       remainder[i] -= self.modulus

    # This will do a bitmask over the entire np.array() and will thus avoid any
    # looping or branching
    remainder -= self.modulus * (remainder >= self.modulus)
    return remainder