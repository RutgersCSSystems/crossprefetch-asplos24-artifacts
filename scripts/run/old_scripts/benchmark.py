import xml.etree.ElementTree as ET
import subprocess
import os, datetime
import sys
import re
from subprocess import Popen, PIPE

APPBENCH=os.environ['APPBENCH']
SCRIPTS=os.environ['SCRIPTS']
APP=SCRIPTS + "/runapps.sh"
INFILE=os.environ['INPUTXML']
QUARTZ=os.environ['QUARTZ']
OUTDIR=os.environ['OUTPUTDIR']
OUTDIRCPY=os.environ['OUTPUTDIR']
OUTARG=str(sys.argv[1])
SHAREDLIB=os.environ['SHARED_LIBS']
STATUSPATH=os.environ['NVMBASE']
flagpath=STATUSPATH + "/flags"

tree = ET.parse(INFILE)
root = tree.getroot()
os.system(APPBENCH + "/install_quartz.sh")

############# Check the tests that are enabled #############
benchmarks = []
for child in root.findall('benchmarks'):
    for subchild in child:
        benchmarks.append(subchild.text)

appprefix = []
for child in root.findall('numabind'):
    for subchild in child:
      appprefix.append(subchild.text)		

def setup():
    os.system("scripts/set_appbench.sh")

def makedb():
    APP = SCRIPTS + "/runapps.sh"
    os.system("killall -9 fio")
    os.system("killall -9 run.sh") 
    os.system("killall -9 runapps.sh") 
    os.system("killall -9 pagerank") 
    os.system("killall -9 db_bench")
    os.system("killall -9 redis-server")
    os.system("killall -9 redis-benchmark")
    os.system("killall -9 wc")
    #os.system("sleep 5")

    #os.system("killall -9 fio")
    #os.system("killall -9 run.sh") 
    #os.system("killall -9 runapps.sh") 
    #os.system("killall -9 pagerank") 
    #os.system("killall -9 db_bench")
    #os.system("killall -9 redis-server")
    #os.system("killall -9 redis-benchmark")
    #os.system("killall -9 wc")
    #os.system("sleep 5")

    
    #Set up interrupt
    os.system("trap hupexit HUP")
    os.system("trap intexit INT")
    os.system("trap"  + " " + "killall -9 fio && killall -9 run.sh && killall -9 runapps.sh && killall -9 pagerank " + "SIGINT")

def intexit():
    # Kill all subprocesses (all processes in the current process group)
    os.system("kill -HUP -$$")

def hupexit():
    # HUP'd (probably by intexit)
    print("Interrupted")
    intexit()

def throttle(membw):
    print "throttling bandwidth to: " + str(membw)
    CMD1 = "sed -i '/read =/c    read =" + str(membw) + "'" + " " +  QUARTZ + "/" + "nvmemul.ini"
    CMD2 = "sed -i '/write =/c   write =" + str(membw) + "'" + " " +  QUARTZ + "/" + "nvmemul.ini"
    os.system(CMD1)
    os.system(CMD2)
    os.system(APPBENCH + "/throttle.sh")

def cleandb():
    print "starting tests"
    #os.system()    


class prettyfloat(float):
    def __repr__(self):
        return "%0.2f" % self


class stats(object):
  
  def __init__(self):
      self.init = 1


  def print_bwlat(self, header, bwidth_set, lat_set, f):
      print "****************************"
      print "Header size " + str(header)
      print "[%s]"%", ".join(map(str,bwidth_set))
      print "[%s]"%", ".join(map(str,lat_set))
      f.write("[%s]\n"%", ".join(map(str,bwidth_set)))
      f.write("[%s]\n"%", ".join(map(str,lat_set)))
      print "****************************\n"
      f.write("\n");


class system(object):

  def __init__(self):
      self.init = 1
      self.diskspace = 0
      self.system_schema = root.find('./system-main')
      os.environ['APPPREFIX'] = "numactl --membind=0"
      os.environ['APP_PREFIX'] = "numactl --membind=0"

  def cleandb(self):
     os.system("")    

  def set_dbdir(self):
      self.dbdir = self.system_schema.find('dbdir').text
      os.environ['TEST_TMPDIR'] = self.dbdir
      print "Database in " + self.dbdir


  def get_diskspace(self, root):
      system_schema = root.find('./system-main')
      partition = system_schema.find('partition').text 
      s = os.statvfs(partition) 
      self.diskspace = (s.f_bavail * s.f_frsize)
      return self.diskspace


  def fitto_diskspace(self, elements, key, value, logspace):  
      usage = ((value + key) * elements) + logspace
      if( usage > self.diskspace):     
          diff = usage - self.diskspace 
          maxele = elements - (diff/(key+value))
          return maxele 
      else:
          return elements


############# Check the tests that are enabled #############

class ParamTest:

    seed_count = 0
    num_tests = 0
    membw = 0
    maxbwtest = 0
    
    output = " "    
    resarr = []    
    xincr = 0
    xmanual = []
    xlegend = []

    #def __init__(self):

    def setvals(self, params):    

        self.seed_count = params.find('seed-count').text
        self.num_tests = params.find('num-tests').text
        self.membw = params.find('membw').text
	self.maxbwtest = params.find('maxbwtest').text

        self.membw_str = str(self.membw);
        self.xincr = int(self.seed_count)


    def runapp(self, APP, index):

        i = 0
        x_values = []

	#Clean the exisiting database; we don't want to read old database
	cleandb();
	print APP +" "+ self.membw_str 

	process = Popen([APP, self.membw_str], \
		  stdout=PIPE)
	(self.output, err) = process.communicate()
	exit_code = process.wait()
        print self.output

	"""
	for line in self.output.splitlines():
	    if re.search(str(benchmarks[0]), line):
		my_set = line.split();
		if my_set[0] in benchmarks:
		    print  my_set[2] + "\t" +  my_set[4]
	    i = i + 1
        """

    # Vary num elements (keys) from base num-elements to num-elements * 2 * num_tests
    def run_membw_test(self, params, bench, numanode):

        count=int(self.membw)      
             
        for loop in range(0, int(self.num_tests)):
            self.num_str = "--num=" + str(count)
   	        #Set the output director
            output = OUTDIRCPY + "/" + bench + "_membw_" + str(count) + numanode
            #Set environmental variable output directory
            os.environ['OUTPUTDIR'] = output	
	    print os.environ['OUTPUTDIR']
	    print "NOT RUNNING THROTTLING"
	    throttle(count)	
            self.runapp(APP, count)
            count = count * int(self.xincr) 
            print output;     


    def run_max_bw_test(self, params, bench): 
	count = 30000
	bench = "maxbw"
        output = OUTDIR + "/" + bench + "_membw_" + str(count)
        os.environ['OUTPUTDIR'] = output
        print os.environ['OUTPUTDIR']
        throttle(count)
        self.runapp(APP, count)
        print count;


    def compile_sharedlib(self, bench):
        SHARED_LIB_APP=SCRIPTS + "/compile_sharedlib.sh"
        print SHARED_LIB_APP + " " + bench
        os.system(SHARED_LIB_APP + " " + bench)

    def complete_path(self, path):
	f = open(flagpath + "/" + path, "w")
	f.write("1")

    def reset_path(self, path):
	f = open(flagpath + "/" + path, "w")
	f.write("0")

    def check_set(self, path):
	data=0
	if(os.path.exists(flagpath + "/" + path)):
	    f = open(flagpath + "/" + path, "r")
	    data=f.read()
	return int(data)

    def version_output(self):
	now = datetime.datetime.now()
	src=OUTDIR
	dest= src + "-" + str(now.strftime("%Y-%m-%d")) + "-" + OUTARG
	print src + " " + dest
        CMD = "cp -r " + src + "  " + dest 
        os.system(CMD)

    def run_fastmemonly(self, membw_test):
	p = self
	if int(p.maxbwtest) == 1 and int(p.check_set("fastonly")) == 0:
	    print p.check_set("fastonly")	
	    p.compile_sharedlib("fastonly")
	    p.run_max_bw_test(membw_test, "")
            p.complete_path("fastonly")
	else:
	    print "fastonly" + " ALREADY SET"


def main():

    p = ParamTest()

    membw_test = root.find('./membw-main')
    is_membw_test = False if int(membw_test.get('enable')) == 0 else True

    if is_membw_test:
        p.setvals(membw_test)
	p.run_fastmemonly(membw_test)

	for j in range(0, len(appprefix)):
	    os.environ['APPPREFIX'] = "numactl --membind=" + str(appprefix[j])
	    os.environ['APP_PREFIX'] = "numactl --membind=" + str(appprefix[j])
	    print os.environ['APP_PREFIX']

            for i in range(0, len(benchmarks)):

		if(int(p.check_set(benchmarks[i])) == 0):
		    print p.check_set(benchmarks[i])
		    p.compile_sharedlib(str(benchmarks[i]))
		    p.run_membw_test(membw_test, str(benchmarks[i]), "-numa-node-" + str(appprefix[j]))
		else:
		    print benchmarks[i] + " ALREADY SET"
		    p.complete_path(str(benchmarks[i]))
		
   	p.reset_path("fastonly")
	for i in range(0, len(benchmarks)):
	    p.reset_path(str(benchmarks[i]))
	
    p.version_output()	
    raise SystemExit

# MAke database 
#setup()
makedb()
main()
exit()
