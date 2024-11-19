# Add&Shift algorithm for modular multiplication

modulus = 17

def addshift(a, b):
  tmp = int(b, 2)
  result = 0
  a = a[::-1]

  for i in range(0, len(a)):
    if a[i] == "1":
      # print(f'{tmp} << {i}')
      result = result + (tmp << i)
    elif a[i] == "0":
      result = result + (0 << i)
    # print(result)
    tmp = int(b, 2)
    i+=1

  return result


def main():
    binary_pairs = [] 
    with open("addshift.txt", "r") as file:
        for line in file:
            binary_pairs.append(line.strip().split())

    for (a, b) in binary_pairs:
      print(bin(addshift(a, b)))
           


if __name__ == "__main__":
    main()
