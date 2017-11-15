# 6.00 Problem Set 3
# 
# Hangman
#


# -----------------------------------
# Helper code
# (you don't need to understand this helper code)
import random
import string

WORDLIST_FILENAME = "words.txt"

def load_words():
    """
    Returns a list of valid words. Words are strings of lowercase letters.
    
    Depending on the size of the word list, this function may
    take a while to finish.
    """
    print "Loading word list from file..."
    # inFile: file
    inFile = open(WORDLIST_FILENAME, 'r', 0)
    # line: string
    line = inFile.readline()
    # wordlist: list of strings
    wordlist = string.split(line)
    print "  ", len(wordlist), "words loaded."
    return wordlist

def choose_word(wordlist):
    """
    wordlist (list): list of words (strings)

    Returns a word from wordlist at random
    """
    return random.choice(wordlist)

# end of helper code
# -----------------------------------

# actually load the dictionary of words and point to it with 
# the wordlist variable so that it can be accessed from anywhere
# in the program
wordlist = load_words()

# your code begins here!


answer = choose_word(wordlist)
print answer

blanks = []
for letter in answer:
        blanks.append("_")

def find_all(a_str, sub):
    start = 0
    while True:
        start = a_str.find(sub, start)
        if start == -1: return
        yield start
        start += len(sub)

spaces = ''.join(blanks)
print spaces
##Intro to game:

if len(answer) > 8:
    guessesleft = len(answer)
else:
    guessesleft = 8
    
lettersleft = "abcdefghijklmnopqrstuvwxyz"
alphabet = list(lettersleft)

availableletters = ''.join(alphabet)
            
print "Welcome to the game of Hangman!"
print "I am thinking of a word that is", len(answer), "letters long."

for i in range(0,guessesleft):
    
    print "+++++++++++++++++++"
    print "You have", guessesleft, "guesses left."
    if i == 0 and spaces != answer:
        print "Avaialable letters:", availableletters
        guess = str(raw_input("Please guess a letter: ")).lower()
        guessesleft -= 1
        try:
            alphabet.remove(guess)
            lessletters = ''.join(alphabet)
            
        except:
            print "That letter has already been used"
            pass

    elif spaces != answer:
        
        print "Avaialable letters:", lessletters
        guess = str(raw_input("Please guess a letter: ")).lower()
        guessesleft -= 1
        try:
            alphabet.remove(guess)
            lessletters = ''.join(alphabet)
            
        except:
            print "That letter has already been used"
            pass

    else:
        print "Congratulations the word is", answer

    if guess in answer:
        eachletter = find_all(answer,guess)
        for i in eachletter:
            blanks[i] = answer[i]
        
            spaces = ''.join(blanks)
            
                
        print "Good guess: ", spaces



    else:
        spaces = ''.join(blanks)
        print "Oops! That letter is not in my word: ", spaces

if spaces == answer:
    print "\n You figured out the word!", spaces

else:
    print "Thanks for the playing, and better luck nextime.\n The word was:",answer
       
     
