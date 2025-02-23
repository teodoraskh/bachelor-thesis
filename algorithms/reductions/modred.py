import numpy as np
import sys

#  Base class for modular reduction algorithms
class ModularReduction:
  def __init__(self, modulus):
          self.modulus = modulus

  def reduce(self, mult):
        raise NotImplementedError("Subclasses must implement the reduce method.")
  
  @classmethod
  def available_algorithms(cls):
        return {subclass.__name__.lower().replace("reduction", ""): subclass 
                for subclass in cls.__subclasses__()}

  def __repr__(self):
        return f"{self.__class__.__name__}(modulus={self.modulus})"


class BarrettReduction(ModularReduction):
  def __init__(self, modulus):
    super().__init__(modulus)
    self.k = self.modulus.bit_length()
    self.mu = (1 << (2 * self.k)) // self.modulus

  def reduce(self, mult):
    approximated_quotient = (mult * self.mu) >> (2 * self.k)
    remainder = mult - approximated_quotient * self.modulus
    # This will do a bitmask over the entire np.array() and will thus avoid any
    # looping or branching
    remainder -= self.modulus * (remainder >= self.modulus)
    # if there are still elements in the remainder array that are greater than modulus, reduce them
    while np.any(remainder >= self.modulus):
      remainder[remainder >= self.modulus] -= self.modulus
    return remainder
  

class MontgomeryReduction(ModularReduction):
    def __init__(self, modulus):
      super().__init__(modulus)
      self.radix = 1 << self.modulus.bit_length() #R = (2 ^ n)
      self.inv_radix = pow(self.radix, -1, self.modulus)
      assert(np.gcd(self.radix, self.modulus) == 1)

    def to_montgomery(self, x):
      return (x * self.radix) % self.modulus

    def from_montgomery(self, acc):
      return (acc * self.inv_radix) % self.modulus

    def reduce(self, mult):
        acc = mult.copy()
        # go through every bit of the modulus
        for _ in range(self.modulus.bit_length()):
            # get lsb of every coefficient found in acc, then do conditional reduction
            LSB = acc & 1
            acc = np.where(LSB == 0, acc >> 1, (acc + self.modulus) >> 1)
        return acc
    

class ShiftAddReduction(ModularReduction):
    def __init__(self, modulus):
        super().__init__(modulus)
    
    # def reduce(self, A, B):
    #     result = np.zeros(len(A) + len(B), dtype=A.dtype)
    #     # Perform shift-and-add
    #     for i, coeff in enumerate(B):
    #       shifted_X = np.roll(A, i)  # Shift X by i positions
    #       shifted_X[:i] = 0  # Zero out the rolled-over elements
    #       result += coeff * shifted_X  # Add to the result

    #     return result

    # def reduce
  

class SchoolbookReduction(ModularReduction):
    def __init__(self, modulus):
      super().__init__(modulus)

    def reduce(self, mult):
        return mult % self.modulus
  
ALGORITHMS = ModularReduction.available_algorithms()