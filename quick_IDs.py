import subprocess
import scanf
import pickle
import os

NO_FILE='dwpaley@gmail.com.no.txt'
with open(NO_FILE) as f:
    no_lines = f.readlines()

paths_ids = dict()

for line in no_lines:
    print(line)
    print(paths_ids.keys())
    if line.strip() not in paths_ids.keys():
        parent = os.path.split(line.strip())[0]
        print(parent)
        new_ids = subprocess.run(['drive', 'id', '-depth=2', parent],
                stdout=subprocess.PIPE).stdout.decode('utf-8').split('\n')
        print(new_ids)
        for line in new_ids:
            id,path = scanf.scanf('"%s" "%s"', line.strip()) or ('','')
            paths_ids[path.lstrip('/')] = id

with open('paths_ids.p', 'wb') as f:
    pickle.dump(paths_ids, f)




