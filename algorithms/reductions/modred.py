import numpy as np
import math
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
    # If we use the Mersenne modulus property:
    # m = 2^k -1 => 2^k eq. 1 (mod 2^k-1)
    # we can split our input number into k-bit chunks
    # the remainder is computed by summing up the k-bit chunks
    def __init__(self, modulus):
        super().__init__(modulus)
        self.k    = math.log2(self.modulus + 1)
        assert self.k == math.floor(self.k), "The modulus is not a Mersenne prime!"
        self.k = int(self.k) # for bitwise operations
        self.mask = (1 << self.k) - 1 # the mask is the modulus but in Mersenne form

    # Find k, and also check if  modulus is a mersenne prime:
    # if m = 7 => 7 = 2^k -1 => 8 = 2^k => k = log_2(8) => k = 3.
    # if k is an integer, then m is mersenne
    
    def reduce(self, mult):
      remainder = mult.copy()
      while np.any(remainder >= self.modulus):
        remainder = (remainder >> self.k) + (remainder & self.mask)
      return remainder
  

class SchoolbookReduction(ModularReduction):
    def __init__(self, modulus):
      super().__init__(modulus)

    def reduce(self, mult):
        return mult % self.modulus
  
ALGORITHMS = ModularReduction.available_algorithms()