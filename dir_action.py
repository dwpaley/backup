#!/usr/bin/env python3.6
import sys
import pickle
import os
from populate_users import User
from functools import partial
import copy

#to do: "assign to all qualified users"


FILE_ROOT = '/home/dwpaley/backuptest/sandbox2/dest/CNILabs_backup/'

USER_FILE = 'users_tools.p'
TOOL_FILE = 'rsync_hosts'
TOOL_FIELDS = ['short_name', 'ssh_user', 'ip', 'port', 'path', 'long_name']
STAFF = [User(f, l, e) for f, l, e in [
    ('Amir', 'Zangiabadi', 'az2476@columbia.edu'),
    ('Cris', 'Belfer', 'cmb2321@columbia.edu'),
    ('Dan', 'Paley', 'dwp2111@columbia.edu'),
    ('Ibrahim', 'Othman', 'io2203@columbia.edu'),
    ('James', 'Vichiconti', 'jv2534@columbia.edu'),
    ('Jen', 'Yu', 'jy2488@columbia.edu'),
    ('Melody', 'Gonzalez', 'mg3779@columbia.edu'),
    ('Nava', 'Ariel-Sternberg', 'na2661@columbia.edu'),
    ]]






with open(USER_FILE, 'rb') as f:
    all_users = pickle.load(f)

tools = []
with open(TOOL_FILE) as f:
    for line in f.readlines():
        tool = {key:val for key,val in zip(TOOL_FIELDS, line.strip().split(','))}
        tools.append(tool)

def menu_prompt(choices, default=None):
    ''' should take a list of 3-tuples (key, menu text, action) and return a
    callable (which I think will be called with a directory path as arg) 
    '''
    switcher = {c[0]:c[2] for c in choices}
    for c in choices:
        print('{}:\t{}'.format(c[0], c[1]))
    prompt = 'Selection: '
    if default: prompt += '[{}] '.format(default)

    inp = False
    while not inp:
        inp = input(prompt) or default
    return switcher[inp]



def line_actions(line):
    LINE_OPTIONS = [
            ('0', 'Assign directory and all subdirectories to ' \
                    'member', assign_member),
            ('1', 'Skip and assign to owners of subdirectories', skip_assign),
            ('2', 'Assign to staff members', assign_staff),
            ('3', 'Assign to nobody', assign_nobody),
            ('4', 'Assign to multiple users', 
                partial(assign_member, multi_assign=True)),
            ('5', 'Skip and save for later', skip_save),
            ('6', 'Skip this and children', skip_all),
            ('7', 'Skip this and siblings', skip_siblings),
            ]


    dir = line[len(FILE_ROOT):]
    print()
    print(dir)

    return menu_prompt(LINE_OPTIONS, default='0')(line)

    
def find_matches(dir, users):
    '''dir is a directory path, users is an iterable of User objects from 
    populate_users. returns a list of User objects.
    '''
    name_matches = []
    for user in users:
        if user.first_name.lower() in dir.lower() or \
                user.last_name.lower() in dir.lower() or \
                os.path.split(dir)[1].lower() in user.first_name.lower() or \
                os.path.split(dir)[1].lower() in user.last_name.lower() or \
                os.path.split(dir)[1].lower() in user.email.lower():
            name_matches.append(user)
    return name_matches

def save_allowed_users(line, owners, multi_assign=None):
    '''takes a directory path and a list of owners. For every subdirectory
    in that directory, writes a file .allowed_users containing the list of
    owners. For every parent of the directory up to FILE_ROOT, adds each owner
    to .allowed_users if they aren't already there.
    '''
    for root, dirs, files in os.walk(line):
        with open(root + '/.allowed_users', 'a') as f:
            for owner in owners: f.write(owner.email + '\n')

    parent = os.path.split(line)[0]
    while (parent + '/').startswith(FILE_ROOT):
        with open(parent + '/.allowed_users', 'a+') as f:
            f.seek(0)
            ftext = f.read()
            for owner in filter(lambda o: o.email not in ftext, owners):
                f.write('{}\n'.format(owner.email))
        parent = os.path.split(parent)[0]

    return multi_assign

    
def build_menu_opts(baseopts, users, multi_assign=None):
    '''
    Takes a menu in the format [(key, menu text, callable), ...] and a list of
    User objects. Enumerates the User objects and prepends them to the given
    menu baseopts, then returns the expanded menu.
    '''
    menu_opts = copy.copy(baseopts)
    if not isinstance(users, list): users = []
    for i, name in enumerate(users):
        menu_opts.insert(0, (
                    str(i), 
                    '{} {}'.format(name.first_name, name.last_name), 
                    partial(save_allowed_users, owners=[name], 
                        multi_assign=multi_assign)
                    ))
    return menu_opts


def assign_member(line, staff=None, multi_assign=None):

    def ASSIGN_OPTIONS(): 
        opts = [
            ('d', 'Done with current directory', 
                lambda l: None),
            ('s', 'Show all matching users', 
                partial(find_matches, users=all_users)),
            ('q', 'Enter a search term (qualified users)',
                lambda l: find_matches(input('Search string: '), qual_users)),
            ('a', 'Enter a search term (all users)',
                lambda l: find_matches(input('Search string: '), all_users))
            ]
        return opts

    #get short and long names of current tool
    dir = line[len(FILE_ROOT):]
    if '/' in dir: 
        current_tool_short_name = dir[:dir.find('/')]
    else: 
        current_tool_short_name = dir
    for tool in tools:
        if tool['short_name'] == current_tool_short_name:
            current_tool_long_name = tool['long_name']

    #get qualified users of current tool
    qual_users = []
    for user in all_users:
        if current_tool_long_name in user.tools:
            qual_users.append(user)

    #from qualified users, find name matches for current dir
    name_matches = staff if staff else find_matches(dir, qual_users)

    #get and execute choice.
    #The various "show users" options return a (possibly empty) list of User
    #objects, while assigning owner or skipping the directory returns None.
    while name_matches is not None:
        menu_opts = build_menu_opts(ASSIGN_OPTIONS(), name_matches, 
                multi_assign=multi_assign)
        action = menu_prompt(menu_opts, default='0')
        name_matches = action(line)

    return line
    
    

def skip_assign(line):
    print('skip and assign to owners of subdirs')

def assign_staff(line):
    assign_member(line, staff=STAFF, multi_assign=True)

def assign_nobody(line):
    save_allowed_users(line, [])
    return line

def skip_save(line):
    print('skip and save for later')

def skip_all(line):
    return line

def skip_siblings(line):
    return os.path.split(line)[0]



def main():
    with open(sys.argv[1]) as f:
        lines = [line.strip() for line in f.readlines()]
    done_lines = []
    for line in lines:
        if list(filter(lambda d:line.startswith(d+'/'), done_lines)): continue
        #in other words, if a parent of this dir is in done_lines, skip it.
        result = line_actions(line)
        if result: done_lines.append(result)


if __name__ == '__main__':
    main()

