#!/usr/bin/env python3

'''
$ populate_users.py <userlist> <rolelist> <outfile> 
to produce a pickled list of User objects with name, email, tool quals list
'''

#Note for later: some pathological users in the database are Badger System,
# test badger, test badger, Pfizer Inc., and '' '' (blank first and last
# names). Their indices in the user list are approximately 0, 1, 2, 44, 45.


import sys
import pickle

USERS_FILE = 'local_data/users.txt'
ROLES_FILE = 'local_data/roles.txt'
USERS_TOOLS_FILE = 'local_data/users_tools.p'


class User(object):
    def __init__(self, first_name, last_name, email):
        self.first_name=first_name
        self.last_name=last_name
        self.email=email
        self.tools=[]

def make_user(s):
    email = s[:s.find(' (')]
    last_name = s[s.find(' (')+2:s.find(', ')]
    first_name = s[s.find(', ')+2:s.find(')\n')]
    return User(first_name, last_name, email)


def main():
    with open(USERS_FILE) as f:
        users = [make_user(line) for line in f.readlines()]
    with open(ROLES_FILE) as f:
        roles = [line.split('\t')[0:2] for line in f.readlines()]
    for email, tool in roles:
        for u in users:
            if u.email == email: u.tools.append(tool)
    with open(USERS_TOOLS_FILE, 'wb') as f:
        pickle.dump(users, f)

if __name__ == '__main__':
    main()
