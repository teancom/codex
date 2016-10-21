from os import listdir
from os.path import isfile, join
import json, string, io

def extract_keys(d,n):
    retval = {}
    if n != "":
        n = n + "."
    for k, v in d.iteritems():
        if isinstance(v, dict):
            retval.update(extract_keys(v,k))
        else:
            retval[n+k] = v
            print "{0}{1}: {2}".format(n, k, v)
    return retval

walkthroughPath = "/data/Projects/starkandwayne/codex/walkthrough"

with io.open(walkthroughPath+"/aws/walkthrough.md", 'r', encoding="utf-8") as walkthroughFile:
    walkthroughText = walkthroughFile.read()

with io.open(walkthroughPath+"/aws/parameters.json", 'r', encoding="utf-8") as walkthroughParamsFile:
    walkthroughParams = json.load(walkthroughParamsFile)
print "Extracting Parameters..."
walkthroughParams = extract_keys(walkthroughParams,'')
print ""

snippetFiles = [f for f in listdir(walkthroughPath) if isfile(join(walkthroughPath, f))]

for snippetFileName in snippetFiles:
    print "Merging in " + snippetFileName + "..."
    snippetFile = io.open(join(walkthroughPath, snippetFileName), 'r', encoding="utf-8")
    snippetText = snippetFile.read()
    walkthroughText = string.replace(walkthroughText, "(( insert_file " + snippetFileName + " ))", snippetText)

print ""
print "Merging in Parameters..."
for k,v in walkthroughParams.iteritems():
    walkthroughText = string.replace(walkthroughText, "(( insert_parameter " + k + " ))", v)

outputFile = io.open("/data/Projects/starkandwayne/codex/aws.md", 'w', encoding="utf-8")
outputFile.write(walkthroughText)
print "\nDone!"
