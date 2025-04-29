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

class SchoolbookReduction(ModularReduction):
    def __init__(self, modulus):
      super().__init__(modulus)

    def reduce(self, mult):
        return mult % self.modulus

class BarrettReduction(ModularReduction):
  def __init__(self, modulus):
    super().__init__(modulus)
    self.k = self.modulus.bit_length()
    self.mu = np.object_((1 << 2 * self.k) // self.modulus)

  def reduce(self, mult):
    assert np.all(mult <= self.modulus**2)
    approximated_quotient = np.multiply(mult, self.mu, dtype=np.object_) >> np.multiply(2, self.k, dtype=np.object_)
    remainder = mult - np.multiply(approximated_quotient,self.modulus, dtype=np.object_)
    # This will do a bitmask over the entire np.array() and will thus avoid any
    # looping or branching
    remainder -= np.multiply(self.modulus, (remainder >= self.modulus), dtype=np.object_)
    # if there are still elements in the remainder array that are greater than modulus, reduce them
    # if np.any(remainder >= self.modulus):
    #   remainder[remainder >= self.modulus] -= self.modulus
    # remainder[remainder >= self.modulus] -= self.modulus
    return remainder
  

class MontgomeryReduction(ModularReduction):
    def __init__(self, modulus):
      super().__init__(modulus)
      self.modulus = np.object_(self.modulus)
      self.radix = np.object_(1 << int(self.modulus).bit_length()) #R = (2 ^ n)
      assert np.gcd(self.radix, self.modulus, dtype=np.object_) == 1, "The modulus and the radix are not coprime!" # for the modular inverse to exist
      self.inv_radix = np.object_(pow(self.radix, -1, self.modulus))
      self.n_prime = np.object_(-pow(self.modulus, -1, self.radix))

    def to_montgomery(self, x):
      # return np.object_(self.reduce(np.object_(x) * self.radix * self.radix, True))
      return np.object_(np.object_(x) * self.radix % self.modulus)

    def from_montgomery(self, x):
      return np.object_((np.object_(x) * self.inv_radix) % self.modulus)
    
    def find_modular_inverse(self, x):
      t, new_t = 0, 1
      r, new_r = self.radix, self.modulus

      while new_r != 0:
        quotient = r // new_r
        t, new_t = new_t, t - quotient * new_t
        r, new_r = new_r, r - quotient * new_r

      if r > 1:
        raise ValueError(f"{self.modulus} has no modular inverse modulo {self.radix}")
      if t < 0:
        t += self.radix
      return -t

    def reduce(self, T):
      # self.n_prime = self.find_modular_inverse(T)
      print("correction: ", self.n_prime)
      m = np.object_((T & (self.radix - 1)) * self.n_prime & (self.radix - 1))
      t = np.object_((T + m * self.modulus) >> self.modulus.bit_length())
      t = np.where(t >= self.modulus, t - self.modulus, t)
      return t

    # NOTE: this vvv also works fine
    # def reduce(self, mult):
    #   # assert np.all(mult <= self.modulus*2)
    #   acc = np.object_(mult.copy())
    #   # go through every bit of the modulus
    #   for _ in range(self.modulus.bit_length()):
    #     # get lsb of every coefficient found in acc, then do conditional reduction
    #     LSB = np.object_(acc & 1)
    #     acc = np.object_(np.where(LSB == 0, np.object_(acc >> 1), np.object_(np.object_(acc + self.modulus) >> 1)))
    #   # acc = np.where(acc >= self.modulus, acc - self.modulus, acc)
    #   return acc


    

class ShiftAddReduction(ModularReduction):
    # If we use the Mersenne modulus property:
    # m = 2^k -1 => 2^k eq. 1 (mod 2^k-1)
    # we can split our input number into k-bit chunks
    # the remainder is computed by summing up the k-bit chunks
    def __init__(self, modulus):
        super().__init__(modulus)
        self.k = self.modulus.bit_length()
        self.k_2 = np.object_(1 << self.k)
        self.mask = np.object_(self.k_2 - 1)
        self.coeff = np.object_(self.k_2 % self.modulus)

    # Find k, and also check if  modulus is a mersenne prime:
    # if m = 7 => 7 = 2^k -1 => 8 = 2^k => k = log_2(8) => k = 3.
    # if k is an integer, then m is mersenne
    
    def reduce(self, mult):
      print(f"bitlength: {self.k}")
      print(f"correction: {self.coeff}")
      remainder = np.object_(mult.copy())
      # while np.any(mult >= self.modulus):
      for _ in range(self.modulus.bit_length()):
        # mask gets least k bits, r >> k removes those k bits
        # print(remainder)
        # by default, mersenne use coeff = 1 because 2^k congr 1 mod modulus
        # so if we find a way to easily precompute coeff...
        hi = np.object_(remainder >> self.k)
        lo = np.object_(remainder & self.mask)
        remainder = np.object_(self.coeff * hi  + lo)
      if np.any(remainder >= self.modulus):
         print("t")
         remainder[remainder>= self.modulus] -= self.modulus
      return remainder

  
ALGORITHMS = ModularReduction.available_algorithms()