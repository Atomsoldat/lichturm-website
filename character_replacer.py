#!/usr/bin/env python
import re
import sys

# mapping of character sequences to Umlaute
REPLACEMENTS = {
    "ae": "ä",
    "oe": "ö",
    "ue": "ü",
    "Ae": "Ä",
    "Oe": "Ö",
    "Ue": "Ü",
    "ss": "ß",
}


def replace_interactively(input_text):
    # Split words, keeping punctuation (tokens list contains words and separators)
    # https://docs.python.org/3/library/re.html#re.split
    # \W represents any non-word character
    # + means one or more
    # (...) defines a capturing group; in this case, using a capturing group
    # adds the matched expression (whitespace and punctuation  and whatnot) to the list of split tokens as well
    tokens = re.split(r"(\W+)", input_text)
    result_tokens = []

    for token in tokens:
        new_token = token
        for match, replacement_string in REPLACEMENTS.items():
            # As long as the sequence still exists in the word
            while match in new_token:
                print(f"Word: {new_token}")
                choice = (
                    input(f"Replace '{match}' with '{replacement_string}'? (y/n) ")
                    .strip()
                    .lower()
                )

                if choice == "y":
                    # Replace only the first occurrence so you can confirm each separately
                    new_token = new_token.replace(match, replacement_string, 1)
                elif choice == "n":
                    # Skip this one, move on to next sequence
                    break
                else:
                    print("Please type 'y' or 'n'.")
        result_tokens.append(new_token)
    return "".join(result_tokens)


def main():
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} input.md output.md")
        sys.exit(1)

    input_file, output_file = sys.argv[1], sys.argv[2]

    with open(input_file, "r", encoding="utf-8") as f:
        input_text = f.read()

    output_text = replace_interactively(input_text)

    with open(output_file, "w", encoding="utf-8") as f:
        f.write(output_text)

    print(f" Finished. Written to {output_file}")


if __name__ == "__main__":
    main()
