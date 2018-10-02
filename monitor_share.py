#!/usr/bin/env python3

import subprocess, random, time, sys, re, pickle
from build_service import service

BACKUP_ROOT = 'CNI'
N_TEST = 50
TEST_SLEEP = 60
ID_CACHE = 'random_ids.p'


def get_name(file_id):
    return service.files().get(fileId=file_id, fields='name').execute()['name']

def poll_ids(file_ids, emailAddress):
    n_total, n_yes = len(file_ids), 0
    for file in file_ids:
        perms = try_until(get_all_perms, 10, 2, file)
        if emailAddress in perms: n_yes +=1
        #else: print(try_until(get_name, 10, 2, file))
    return n_yes/n_total

def try_until(func, max_tries, sleep_time, *argv):
    for _ in range(max_tries):
        try:
            return func(*argv)
        except KeyboardInterrupt:
            raise
        except Exception as err:
            failed_because = err
            time.sleep(sleep_time)
    raise failed_because


def get_all_perms(fileId):
    permissions = []
    response = service.permissions().list(
            fileId=fileId, 
            fields='permissions/emailAddress, nextPageToken'
            ).execute()
    for perm in response['permissions']:
        permissions.append(perm['emailAddress'])
    while 'nextPageToken' in response.keys():
        pageToken = response['nextPageToken']
        response = service.permissions().list(
                fileId=fileId, 
                fields='permissions/emailAddress, nextPageToken',
                pageToken=pageToken 
                ).execute()
        for perm in response['permissions']:
            permissions.append(perm['emailAddress'])
    return permissions



def main():
    t_start = time.time()

    test_email = sys.argv[1]

    try:
        with open(ID_CACHE, 'rb') as f:
            sample_ids = pickle.load(f)
    except FileNotFoundError:
        sample_ids = []
        id_template=re.compile(r'"(\S+)"\s+"/(.+)"')
        find_result = subprocess.run(['find', BACKUP_ROOT, '-not', '-name', 
                '.allowed_users*'], stdout=subprocess.PIPE).stdout. \
                decode('utf-8').split('\n')
        print('Found {} items'.format(len(find_result)))
        sample_paths = random.sample(find_result, N_TEST)
    
        for path in sample_paths:
            print('Retrieving id: {}/{}'.format(len(sample_ids), N_TEST))
            id_out = subprocess.run(
                    ['drive', 'id', path], stdout=subprocess.PIPE
                    ).stdout.decode('utf-8')
            id = id_template.search(id_out).groups()[0]
            sample_ids.append(id)

        with open(ID_CACHE, 'wb') as f:
            pickle.dump(sample_ids, f)

    while True:
        shared_fraction = poll_ids(sample_ids, test_email)
        t_elapsed = int(time.time() - t_start)
        if len(sys.argv) > 2:
            out_file = sys.argv[2]
            with open(out_file, 'a') as f:
                f.write('{},{:.0f}\n'.format(t_elapsed, shared_fraction*100))
        else:
            print('{} s elapsed: {:.0f}% shared'.format(
                t_elapsed, shared_fraction*100))
        time.sleep(TEST_SLEEP)

if __name__=='__main__':
    main()




