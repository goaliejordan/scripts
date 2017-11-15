#!/usr/bin/python
#
#  This script will create LDEV's on VSP array using raidcom commands 
#   
#  To run enter the horcm instance that correspond with the array should be last 3 digits of the serial # 
#  > create_ldev.py 149
#  
# 
# Version 2.5 changed min LDEV size to 3990G
# Version 3 added pool look up, manual name setting of LDEV's for LDOM use, updated HMO options

script_ver = 3 # used to verify version, displayed at startup, summary screen and log file.

import sys, subprocess, os, datetime, string, time, re 

#### Global Variables
time_stamp = datetime.datetime.today().strftime("%m-%d-%Y %H:%M")

# Global Variables
raidcom_cmd = '/HORCM/usr/bin/raidcom '
ldevs = []  # list of devices
hosts = []  # list of hosts used to create host groups & provision ports/ldevs
log_file_location = '/hds_data/scripts/logs/'
cl_ports_odd = []
cl_ports_even = []
ldevs_free = []  # list of free ldevs below std_cu_limit that can be used for new devices
pools = []  # object list of pools with name and capacity info

# tier settings
# Device Mgr view Performance = custom 1, Standard = Custom 2
# SVP Performance = 6, Standard = 7
tier_perf = 6
tier_std = 7

# Device size Limits Min=8G / Max= 3990G
ldev_min = 8  #GB  8 to 3990
ldev_max = 3990  #GB  8 to 3990

## CU assignment limit for standard LDEVS set by SOPs  0 --> 0x47FF (dec 18,431)
std_cu_limit = 18431

# CL pair Limit     ## used to prevent syntax error or runaway job and act as roadblock to installing a host with 4 pair or 8 HBA's further design would be required.
cl_pair_limit = 3

# Host Mode settings
hm_linux = 'LINUX' #00
hm_solaris = 'SOLARIS' #09
hm_windows = 'WIN_EX' # 0c
hm_vmware = 'VMWARE_EX' #21
hmo_cluster = '2 '  # Host Mode Options - Solaris Veritas Cluster, Windows Cluster, Oracle RAC
hmo_vmware = '40 63'  # Host Mode Options - VMware ESX hosts
hmo_windows = '40 '  # default = for win hosts to include V-VOL expansion on the fly
## Windows standalone - WIN 40 /  Windows Cluster WIN 2 40
## Linux standalone - LINUX / Linux Cluster LINUX 2
## Solaris standalone - SOLARIS / Solaris Cluster SOLARIS 2
## Vmware standalone or cluster = VMWARE_EX 40 63


## function to check the lock status of the array
def fn_checkArray():

   ## raw command  --> raidcom get resource -IM149  
   arrayTestcmd = subprocess.Popen(raidcom_cmd + ' get resource ' + ' -IM' + str(horcm_instance), stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True)
   output, err = arrayTestcmd.communicate()
   arrayTest = output
   arrayTest_temp = []
   arrayTest_temp = string.split(arrayTest)
   if arrayTest_temp[8] == 'Locked':  # third column returns Locked/Unlocked
       print 'The array is currently Locked by', arrayTest_temp[10], 'The script can not continue.'
       exit()
   else:
      pass # keep on processing the rest of the script
   return;
  
## function lock array   
def fn_lockArray():

    arrayLockcmd = subprocess.Popen(raidcom_cmd + ' lock resource ' + ' -IM' + str(horcm_instance), stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True)
    output, err = arrayLockcmd.communicate()
    arrayLock = output
    print 'array', horcm_instance, 'is now locked\n'
    return;

## function unlock array    
def fn_unlockArray():

    arrayunLockcmd = subprocess.Popen(raidcom_cmd + ' unlock resource ' + ' -IM' + str(horcm_instance), stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True)
    output, err = arrayunLockcmd.communicate()
    arrayunLock = output
    print 'array', horcm_instance, 'is now unlocked'
    print '********************************\n\n'
    return;
      
## function create LDEVs
def fn_createLdev():
    for ldev in ldevs:  
       ldevCreate = subprocess.Popen(raidcom_cmd + ' add ldev -ldev_id ' + hex(ldev.number) + ' -pool ' + str(ldev.pool) + ' -capacity ' + str(ldev.size) + ' -IM' + str(horcm_instance), stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True)
       output, err = ldevCreate.communicate()
       time.sleep(3) # wait 3 sec  
    return;

## function set tier policy on LDEVs     
def fn_setTier(): 
#  raidcom modify ldev -ldev_id 0x80 -status new_page_allocation middle -status enable_relocation_policy 7 -IM149 
#  raidcom modify ldev -ldev_id 0x99 -ldev_name  test12345 -IM149
   
   for ldev in ldevs: 
      ldevSetTier = subprocess.Popen(raidcom_cmd + ' modify ldev -ldev_id ' + hex(ldev.number) + ' -status new_page_allocation middle -status enable_relocation_policy ' +  str(ldev.tier) +' -IM' + str(horcm_instance), stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True)
      ldevSetName = subprocess.Popen(raidcom_cmd + ' modify ldev -ldev_id ' + hex(ldev.number) + ' -ldev_name ' + str(ldev.name) + ' -IM' + str(horcm_instance), stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True)
      output, err = ldevSetTier.communicate()
      output, err = ldevSetName.communicate()
      if tier == 6:  # GE Peformance tier
        print 'Tier policy for ' + hex(ldev.number) + ' set to GE Performance' 
      if tier == 7:  # GE Standard tier
        print 'Tier policy for ' + hex(ldev.number) + ' set to GE Standard'
   return;

## function create host group 1 host per CL port auto generate _p1/_p2 _p3/_p4 into name  * clusters will be created with one name * 
def fn_createHostGroup():
   
   ##  raw command --> # raidcom add host_grp -port cl1-a -host_grp_name esx01_p1 -IM149 
   y = 1  #used to increment between multiple HBA's on a host _p1, _p3
   for cl in cl_ports_odd:
      createHG_odd = raidcom_cmd + ' add host_grp -port ' + str(cl.name) + ' -host_grp_name ' + str(hostname) + '_p' + str(y) + ' -IM' + str(horcm_instance)
      output = os.popen(createHG_odd)
      cl_odd_temp = output
      #capture new GID # to be used to add LDEVs into host group
      ##getHostGroups = raidcom + ' get host_grp -port ' + str(port.name) + ' -s ' + array_sn + ' -IM' + horcm_inst
      for line in cl_odd_temp:   # array returns 3(0x3)  dec & hex so you need to split them to get the value
         line = line.strip()
         groupfields = line.split()
         gid_temp = groupfields[4].split('(')
         cl.gid = gid_temp[0]
         print 'Created host group ' + str(hostname) + '_p' + str(y) + ' on ' + cl.name + '-' + cl.gid
      y = y + 2 # p1, p3 odd fabric
      
   y = 2  #used to increment between multiple HBA's on a host _p2, _p4
   for cl in cl_ports_even:
      createHG_even = raidcom_cmd + ' add host_grp -port ' + str(cl.name) + ' -host_grp_name ' + str(hostname) + '_p' + str(y) + ' -IM' + str(horcm_instance)
      output = os.popen(createHG_even)
      cl_even_temp = output
      #capture new GID # to be used to add LDEVs into host group
      ##getHostGroups = raidcom + ' get host_grp -port ' + str(port.name) + ' -s ' + array_sn + ' -IM' + horcm_inst
      for line in cl_even_temp:   # array returns 3(0x3)  dec & hex so you need to split them to get the value
         line = line.strip()
         groupfields = line.split()
         gid_temp = groupfields[4].split('(')
         cl.gid = gid_temp[0]
         print 'Created host group ' + str(hostname) + '_p' + str(y) + ' on ' + cl.name + '-' + cl.gid
      y = y + 2 # p2, p4 odd fabric
      
   return;
 
## function add host wwn to host group 
def fn_addPwwnHostGroup():

   # raw command --> raidcom add hba_wwn -port cl1-a-1 esx01_03_p1 -hba_wwn 1234567832119876 -IM149
   # raw command --> raidcom set hba_wwn -port cl1-a-1 esx01_03_p1 -hba_wwn 1234567832119876 -wwn_nickname esx01_03_p1 -IM149
   y = 1  #used to increment between multiple HBA's on a host _p1, _p3
   for cl in cl_ports_odd:
      for pwwn in cl.pwwn_list:
         addPwwn_odd = raidcom_cmd + ' add hba_wwn -port ' +  str(cl.name) + '-' + cl.gid + ' ' + str(hostname) + '_p' + str(y) + ' -hba_wwn ' + pwwn.pwwn + ' -IM' + str(horcm_instance)
         output = os.popen(addPwwn_odd)
         time.sleep(10) # wait 10 sec
         setPwwn_odd = raidcom_cmd + ' set hba_wwn -port ' +  str(cl.name) + '-' + cl.gid + ' ' + str(hostname) + '_p' + str(y) + ' -hba_wwn ' + pwwn.pwwn + ' -wwn_nickname ' + str(pwwn.alias) + ' -IM' + str(horcm_instance)
         output = os.popen(setPwwn_odd)
         print 'pwwn - ' + pwwn.pwwn + ' added to ' + str(hostname) + '_p' + str(y) + ' on ' + cl.name + '-' + cl.gid
      y = y + 2 # p1, p3 odd fabric
    
   y = 2  #used to increment between multiple HBA's on a host _p2, _p4
   for cl in cl_ports_even:
      for pwwn in cl.pwwn_list:
         addPwwn_even = raidcom_cmd + ' add hba_wwn -port ' +  str(cl.name) + '-' + cl.gid + ' ' + str(hostname) + '_p' + str(y) + ' -hba_wwn ' + pwwn.pwwn + ' -IM' + str(horcm_instance)
         output = os.popen(addPwwn_even)
         time.sleep(10) # wait 10 sec
         setPwwn_even = raidcom_cmd + ' set hba_wwn -port ' +  str(cl.name) + '-' + cl.gid + ' ' + str(hostname) + '_p' + str(y) + ' -hba_wwn ' + pwwn.pwwn + ' -wwn_nickname ' + str(pwwn.alias) + ' -IM' + str(horcm_instance)
         output = os.popen(setPwwn_even)
         print 'pwwn - ' + pwwn.pwwn + ' added to ' + str(hostname) + '_p' + str(y) + ' on ' + cl.name + '-' + cl.gid
      y = y + 2 # p2, p4 odd fabric
      
   return;

## function add LDEVs into each host group created   
def fn_addLdevHostGroup():

   y = 1  #used to increment between multiple HBA's on a host _p1, _p3
   for cl in cl_ports_odd:  # loop through all the CL odd ports  -> raw command # raidcom add lun -port cl5-a-1 test12345 -ldev_id 0x98 -IM149)
      for ldev in ldevs:
         ldevAddHG_odd = subprocess.Popen(raidcom_cmd + ' add lun -port ' + cl.name + '-' + cl.gid  + ' ' + hostname + '_p'  + str(y)  + ' -ldev_id ' + hex(ldev.number) +' -IM' + str(horcm_instance), stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True)
         output, err = ldevAddHG_odd.communicate()
         print 'LDEV ' + hex(ldev.number) + ' added to ' + cl.name + '-' + cl.gid + ' host group-' + hostname + '_p'  + str(y) 
      y = y + 2 # x = p1, p3 odd fabric
      
   y = 2  #used to increment between multiple HBA's on a host _p2, _p4
   for cl in cl_ports_even:  # loop through all the CL even ports  -> raw command # raidcom add lun -port cl5-a-1 test12345 -ldev_id 0x98 -IM149)
      for ldev in ldevs:
         ldevAddHG_even = subprocess.Popen(raidcom_cmd + ' add lun -port ' + cl.name + '-' + cl.gid  + ' ' + hostname + '_p'  + str(y)  + ' -ldev_id ' + hex(ldev.number) +' -IM' + str(horcm_instance), stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True)
         output, err = ldevAddHG_even.communicate()
         print 'LDEV ' + hex(ldev.number) + ' added to ' + cl.name + '-' + cl.gid + ' host group-' + hostname + '_p'  + str(y) 
      y = y + 2 # x = p2, p4 even fabric
      
   return;

## function ask user what LDEV size to create   
def fn_inputLdevSize():

   global ldev_size, ldev_name
   ldev_size = raw_input("What size LDEV do you want to create?  (min 8G / max 3990G) - ")
   if ldev_size.endswith('G'):  #test for valid input as well as min/max ldev size
       ldev_size_temp = int(ldev_size.rstrip('G'))
       if ldev_size_temp < ldev_min or ldev_size_temp > ldev_max:  
           print 'size outside GE standards'
           exit()
       if ldev_naming == 'manual':
          ldev_name = raw_input("Enter the name for this LDEV (typically host name for a LDOM) ")  # this way the LDOM name is registered on the LDEV.
   else:
       print 'LDEV input syntax error'
       exit()
   return;

## function create log file when job is finished   
def fn_updateLogFile():

   log_file = log_file_location + 'now#_' + ticket_num + '.log'
   file = open(log_file, 'a+')
   file.write ('\n\n**** Start of Job ****')
   file.write ('\nScript Ver-' + str(script_ver))
   file.write ('\nTime stamp-' + time_stamp)
   file.write ('\nService Now # ' + ticket_num)
   file.write ('\nTechnician SSO= ' + sso_id)
   file.write ('\nHost name- ' + hostname)
   file.write ('\nTier policy- ' + str(tier))
   file.write ('\nHost Mode- ' + str(host_mode))
   file.write ('\nHost Mode Options- ' + str(hm_option) + '\n')
   y = 1  #used to increment between multiple HBA's on a host _p1, _p3
   for cl in cl_ports_odd:
      for pwwn in cl.pwwn_list:
         file.write('\npwwn - ' + pwwn.pwwn + ' added to ' + str(hostname) + '_p' + str(y) + ' on ' + cl.name + '-' + cl.gid)
      y = y + 2 # p1, p3 odd fabric
       
   y = 2  #used to increment between multiple HBA's on a host _p2, _p4    
   for cl in cl_ports_even:
      for pwwn in cl.pwwn_list:
         file.write('\npwwn - ' + pwwn.pwwn + ' added to ' + str(hostname) + '_p' + str(y) + ' on ' + cl.name + '-' + cl.gid)  
      y = y + 2 # p2, p4 odd fabric
       
   file.write ('\nThe following LDEVs were created.\n\n')
   for ldev in ldevs:
      getLDEV = subprocess.Popen(raidcom_cmd + ' get ldev -ldev_id ' + hex(ldev.number) + ' -fx -IM' + str(horcm_instance), stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True)
      output, err = getLDEV.communicate()
      file.write ('\n' + output) 
   file.write('\n\n**** End of Job ****\n\n')
   file.close()

   return;  

## function set Host mode on each host group + HMO if it is a cluster
def fn_setHostMode():

   ## raw command --> #  raidcom modify host_grp -port cl1-a-1 -host_grp_name ed -host_mode win -host_mode_opt 2,63 -IM149
   for cl in cl_ports_odd:
      y = 1  # p1, p3 odd fabric
      # Set Host Mode
      if hm_option != None:  #run cmd with Host Mode options HMO set to '' for linux & solaris standalone systems
         setHM_odd = subprocess.Popen(raidcom_cmd + ' modify host_grp -port ' + str(cl.name) + '-' + cl.gid + ' -host_grp_name ' + str(hostname) + '_p' + str(y) + ' -host_mode ' + str(host_mode) + ' -host_mode_opt ' + str(hm_option) + ' -IM' + str(horcm_instance), stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True)
      else:  # run cmd without Host Mode Options
         setHM_odd = subprocess.Popen(raidcom_cmd + ' modify host_grp -port ' + str(cl.name) + '-' + cl.gid + ' -host_grp_name ' + str(hostname) + '_p' + str(y) + ' -host_mode ' + str(host_mode) + ' -IM' + str(horcm_instance), stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True)
         output, err = setHM_odd.communicate()
      y = y + 2 # x = p1, p3 odd fabric
      
   for cl in cl_ports_even:
      y = 1  # p2, p4 odd fabric
      # Set Host Mode
      if hm_option != None:  #run cmd with Host Mode options
         setHM_even = subprocess.Popen(raidcom_cmd + ' modify host_grp -port ' + str(cl.name) + '-' + cl.gid + ' -host_grp_name ' + str(hostname) + '_p' + str(y) + ' -host_mode ' + str(host_mode) + ' -host_mode_opt ' + str(hm_option) + ' -IM' + str(horcm_instance), stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True)
      else:  # run cmd without Host Mode Options
         setHM_even = subprocess.Popen(raidcom_cmd + ' modify host_grp -port ' + str(cl.name) + '-' + cl.gid + ' -host_grp_name ' + str(hostname) + '_p' + str(y) + ' -host_mode ' + str(host_mode) + ' -IM' + str(horcm_instance), stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True)
      output, err = setHM_even.communicate()
      y = y + 2 # x = p2, p4 odd fabric
      
   return;

## function find next free LDEV #
def  fn_findFreeLdev():

   global ldevs_free
   x=0
   while x < std_cu_limit:  # create list of all possible ldev #'s later the script will remove the ones that are in use.
      ldevs_free.append(x)
      x=x+1
   ## raw command --> #  raidcom get ldev -ldev_list defined -IM149 | grep ^LDEV\ :
   find_free_ldev_cmd = raidcom_cmd + ' get ldev -ldev_list defined ' + ' -IM' + str(horcm_instance) + ' | grep ^LDEV\ :' 
   output = os.popen(find_free_ldev_cmd)
   print ('\nlooking for a free LDEV...')
   for line in output:  #find the last LDEV in use on the array that is less than 18432 (47:ff) 
      line = line.strip()
      groupfields = line.split()
      used_ldev = groupfields[2]
      if re.search('\d+', used_ldev):
         if int(used_ldev) < std_cu_limit:  # limit set at top of script per SOPs
            ldevs_free.remove(int(used_ldev))  # create list of available LDEVs  
   sorted(ldevs_free)  # ensure list is sorted lowest to highest
   return;

## function to find available pools + capacity   
def fn_findPools():
    
   ## raw cmd --> # raidcom get dp_pool -IM149   AV_CAP = Available storage, TP_CAP = Physical Pool size, TL_CAP = subscribed storage   
   # read in pools from array
   get_pools = raidcom_cmd + ' get dp_pool ' + ' -IM' + str(horcm_instance)
   output_pools = os.popen(get_pools)
   for line in output_pools:
      line = line.strip()
      groupfields = line.split()
      pid = groupfields[0]
      av_cap = groupfields[3]  # available capacity in pool physical/real
      tp_cap = groupfields[4]  # physical size of pool
      tl_cap = groupfields[10] # amount of storage subscribed to the pool.  GE std is to set subscription of pool to 120% of physical capacity
      name = ''  #blank for now added further down the script
      if re.search('\d+', pid):  # pulls PID #
         av_cap = int(av_cap) / 1024 / 1024  # convert from MB to TB  
         tp_cap = int(tp_cap) / 1024 / 1024
         tl_cap = int(tl_cap) / 1024 / 1024
         sub_free_cap = (tp_cap * 1.2) - tl_cap  # physical size * 1.2 - subscribed capacity = virtual free cap (amount that can be carved to hosts.
         pools.append(poolObj(pid, name, av_cap, tp_cap, tl_cap, sub_free_cap ))  #data is in TB
         #print pid, name, av_cap, tp_cap, tl_cap, sub_free_cap
   #print array_name
   
   ## read pool name using different raidcomd cmd add  add name into list pools
   get_pool_name = raidcom_cmd + ' get pool -key opt ' + ' -IM' + str(horcm_instance)
   output_pool_name = os.popen(get_pool_name)
   pool_name = []
   for line in output_pool_name:
      line = line.strip()
      groupfields = line.split()
      pid = groupfields[0]
      name = groupfields[3]
      if re.search('\d+', pid):  # pulls PID #
         pool_name.append(poolObj(pid, name))  
         #print pid, name
         
   for pool in pools:  # list pools does not have the name 
      for pool_n in pool_name:  #list pool_name has the pool name and PID only.  you need to combine the two.
         if pool_n.pid == pool.pid:
            pool.name = pool_n.name
      #print pool.pid, pool.name, pool.free_capacity, pool.phy_size, pool.sub_capacity
   return;
    
class LdevObj(object):
   """__init__() functions the class constructor"""
   def __init__(self, number=None, name=None, size=None, tier=None, pool=None, array=None):
      self.number = number
      self.name = name
      self.size = size
      self.tier = tier
      self.pool = pool
      self.array = array
      
class clPortObj(object):  #  list of hosts that can access devices.  1 host std multiple for VMware / RAC clusters. Reference back to class clPairObj
   """__init__() functions the class constructor"""
   def __init__(self, name=None, pwwn_list=[], gid=None):
     self.name = name
     self.pwwn_list = pwwn_list
     self.gid = gid
     
class pwwnObj(object):  #  list of pwwn & alias.  Reference back to class clPairObj - pwwn_list
   """__init__() functions the class constructor"""
   def __init__(self, pwwn=None, alias=None):
     self.pwwn = pwwn
     self.alias = alias

class poolObj(object):  #  list of pools
   """__init__() functions the class constructor"""
   def __init__(self, pid=None, name=None, free_capacity=None, phy_size=None, sub_capacity=None, sub_free_cap=None):
     self.pid = pid  # Pool PID #
     self.name = name # Pool name take from SVP usually truncated
     self.free_capacity = free_capacity # actual free space left in pool
     self.phy_size = phy_size # physical size of the pool
     self.sub_capacity = sub_capacity # Subscribed Capacity can grow up to 120% of pool size.
     self.sub_free_cap = sub_free_cap # Amount of storage that can be subscribed to the pool  (120% of physical cap - sub_capacity = sub_free_cap)
     
###############      
## Main code ##
###############

## error check - check to see if the horcm instance was included on start cmd if not stop script
if len(sys.argv) < 2: 
       print 'You forgot to include the HORCM instance for the array'
       print '  - example # add_storage.py 149'
       print '  - script aborted - '
       sys.exit()

horcm_instance = sys.argv[1]  #import horcm instance from cmd line.

## check to see if the array is unlocked abort script if not
fn_checkArray();
### works but if you abort the script the array will stay locked and you'll be locked out

os.system('clear') #clear screen
print '\n***********************************************'
print '\n\nThis script will create a new host group'
print '\n   and devices on a Hitachi VSP SAN array.'
print '\n   script version', script_ver
print '\n***********************************************\n\n'

## lock resource
fn_lockArray();

ticket_num = raw_input("What is the ticket # ")  # used for logging
sso_id = raw_input("What is your SSO # ") # used for logging
hostname = raw_input("What is the hostname for the host or cluster? (tnsd12345 or tnvp001_tnvp003)- ")
host_mode_input = raw_input("What is the host OS (L)inux, (S)olaris, (V)Mware, (W)indows? - ")
host_count = 1 # set default node count = 1
cluster_input = raw_input("Is this a cluster? (y)es / (n)o ")
if host_mode_input  == "L" or host_mode_input == "l":  # check for valid host mode options
   if cluster_input == "yes" or cluster_input == "y":
      host_mode = hm_linux
      hm_option = hmo_cluster
   else:
      host_mode = hm_linux
      hm_option = None
elif host_mode_input == "S" or host_mode_input == "s":
   if cluster_input == "yes" or cluster_input == "y":
      host_mode = hm_solaris
      hm_option = hmo_cluster
   else:
      host_mode = hm_solaris 
      hm_option = None
elif host_mode_input == "V" or host_mode_input == "v":
   if cluster_input == "yes" or cluster_input == "y":
      host_mode = hm_vmware
      hm_option = hmo_vmware
   else:
      host_mode = hm_vmware 
      hm_option = hmo_vmware
elif host_mode_input == "W" or host_mode_input == "w":
   if cluster_input == "yes" or cluster_input == "y":
      host_mode = hm_windows
      hm_option = hmo_windows + hmo_cluster
   else:
      host_mode = hm_windows
      hm_option = hmo_windows 
else:
    print 'host or cluster mode syntax error'
    fn_unlockArray();
    exit()

if cluster_input == "yes" or cluster_input == "y":
   host_count = raw_input("How many hosts will be in the cluster? - ")

ldev_tier = raw_input("What Tier ? ('perf' or 'std')- ")
if ldev_tier == 'std':  # check for valid tier options std/perf only choice
    tier = tier_std
elif ldev_tier == 'perf':
    tier = tier_perf
else:
    print 'tier syntax error'
    fn_unlockArray();
    exit()
    
fn_findPools();  # print out pool capacity details

# display the available pools
print 'Array - ' + horcm_instance + ' has the following pools.'  
for pool in pools:
    print 'Pool ID #' + pool.pid + ' Name = ' + pool.name + ' Subscribed free space = ' + str(pool.sub_free_cap) + ' TB ' 
print '\nUse external pools unless they are full.  CMD devices and UR should be on internal pools if possible.' 

ldev_pool = raw_input("What pool ID do you want to use? - ")
##  add later - Pool Performance 
##  add later - error trap if free space is below 10% or something 

ldev_count = raw_input ("How many LDEVs do you want to create for the new host? ")
if int(ldev_count) == 1:  ##  if you input 1 LDEV don't ask if the size is the same or not
   ldev_same = "yes"   
else:
   ldev_same = raw_input("Will the LDEVs all be the same size (y)es or (n)o ")
   
## Manual LDEV names should be used for LDOMs.  The LDEV name should reflect the host name of the LDOM.
ldev_name_option = raw_input ("Do you want to manually control LDEV names? (auto will use host name). (y)es or (n)o ")
if ldev_name_option == "yes" or ldev_name_option == "y":
   ldev_naming = 'manual'
elif ldev_name_option == "no" or ldev_name_option == "n":
   ldev_naming = 'auto'
else:
   print 'ldev name mode syntax error'
   fn_unlockArray();
   exit()  
   
## find next free LDEV number
fn_findFreeLdev();   # returns list of free ldev #'s between 0x0 and 0x47FF 

if ldev_same == "yes" or ldev_same == "y":
    fn_inputLdevSize();
    i = 0
    while i < int(ldev_count):
       ldev_num_temp = ldevs_free[0]    # take lowest # ldev from list of free ldevs
       ldevs.append(LdevObj(ldev_num_temp)) 
       ldevs[i].size = ldev_size
       ldevs[i].pool = ldev_pool
       if ldev_naming == 'auto': 
          ldevs[i].name = hostname  # apply hostname to ldev name
       else:
          ldevs[i].name = ldev_name # apply user input to ldev name typically LDOM server name
       ldevs[i].tier = tier
       ldevs[i].number = ldev_num_temp
       ldevs_free.remove(ldev_num_temp)  # remove ldev from list of free ldevs
       i = i + 1
   
elif ldev_same == "no" or ldev_same == "n":
   i = 0
   while i < int(ldev_count):
      ldev_num_temp = ldevs_free[0]    # take lowest # ldev from list of free ldevs
      fn_inputLdevSize();
      ldevs.append(LdevObj(ldev_num_temp))
      ldevs[i].size = ldev_size
      ldevs[i].pool = ldev_pool
      if ldev_naming == 'auto':
         ldevs[i].name = hostname # apply hostname to ldev name
      else:
         ldevs[i].name = ldev_name # apply user input to ldev name typically LDOM server name
      ldevs[i].tier = tier
      ldevs[i].number = ldev_num_temp
      ldevs_free.remove(ldev_num_temp)  # remove ldev from list of free ldevs
      i = i + 1
   
## Enter the number of CL-Pairs required
cl_count = raw_input ("How many CL Pairs are required for this host or cluster? ")
if int(cl_count) > int(cl_pair_limit):  ## pair limit of 3 or 6 HBA's per host
   print '\n\nHosts are limited to 3 pair or 6 HBAs.  Review with Storage Engineering Team for 4 or more pairs'  
   fn_unlockArray();
   exit()

## Loop through # of CL pairs, sub loops for hosts on each pair
for i in range(int(cl_count)):  # enter array port and host pwwn
   print 'Create pair #', i+1 # plus 1 added because range starts at 0
   cl_port_p1 = raw_input ("Enter the ODD CL-Port to be used (ex. cl5-a) ? ")
   cl_ports_odd.append(clPortObj(cl_port_p1))
      
   cl_port_p2 = raw_input ("Enter the EVEN CL-Port to be used (ex. cl6-a) ? ")
   cl_ports_even.append(clPortObj(cl_port_p2))
   print '********'
   
## add test for valid odd/even pair later
   
for cl in cl_ports_odd:
   print 'CL ODD Port ', cl.name
   cl.pwwn_list = []
   for x in range(int(host_count)):  # loop through host count
      pwwn_p1 = raw_input ("Enter the host pwwn (ex. aaaabbbbccccdddd) ? ")  
      pwwn_alias_p1 = raw_input ("Enter the pwwn alias (ex tnsd001_hba1_p1) ? ")
      cl.pwwn_list.append(pwwnObj(pwwn_p1, pwwn_alias_p1)) 
   
for cl in cl_ports_even:
   print 'CL EVEN Port ', cl.name
   cl.pwwn_list = []
   for x in range(int(host_count)):  # loop through host count
      pwwn_p2 = raw_input ("Enter the host pwwn (ex. aaaabbbbccccdddd) ? ")  
      pwwn_alias_p2 = raw_input ("Enter the pwwn alias (ex tnsd001_hba2_p2) ? ")
      cl.pwwn_list.append(pwwnObj(pwwn_p2, pwwn_alias_p2)) 
   
   ## raidcom cmd will fail if pwwn > 16 characters
   ## add test for valid input later??????

## print to screen for verification before doing the work
os.system('clear') #clear screen
print '\nThe script is about to provision storage.\n'
print '\nScript Ver=', script_ver
print 'Ticket= ', ticket_num 
print 'Technician SSO= ', sso_id
print 'Host= ' + hostname + ' will be added to HDS array xxx' + horcm_instance, 'and set as a', str(host_mode), 'host with the following HMOs', str(hm_option), '\n'
for cl in cl_ports_odd:
   print '   Port-' + str(cl.name) 
   for pwwn in cl.pwwn_list:  
      print '        pwwn-' + str(pwwn.pwwn) + ' alias-' + str(pwwn.alias)
      
for cl in cl_ports_even:
   print '   Port-' + str(cl.name) 
   for pwwn in cl.pwwn_list:  
       print '        pwwn-' + str(pwwn.pwwn) + ' alias-' + str(pwwn.alias)
       
print '\n'  # add line space
for ldev in ldevs:
   print '  LDEV-', hex(ldev.number), ' Size-', ldev.size, 'in pool #', ldev.pool, 'tier-', ldev_tier 
print '\n**** Warning ****\n'
print 'Are you sure you want to continue? \n\n**** Warning ****\n'
input = raw_input("Enter (y)es to continue (n)o to abort: ")
if input == "yes" or input == "y":
   pass
elif input == "no" or input == "n":
   print "Script aborted."
   fn_unlockArray();
   exit()
   
## create Host Group
fn_createHostGroup();
print 'waiting 30 sec for Host Groups to be created.'
time.sleep(30) # wait 30 sec

## set host mode options
fn_setHostMode();

## add pwwn to host group
fn_addPwwnHostGroup();
 
##  Create LDEVs
fn_createLdev();
print 'waiting 30 sec for LDEVs to be created before applying tiering policy...'
time.sleep(30) # wait 30 sec

##  Set tier policy on LDEVs
fn_setTier();

## add LDEV's to host group
fn_addLdevHostGroup();

## unlock resource
fn_unlockArray();

## Create log file /hds_data/scripts/logs  # raidcom get ldev on newly created devices
fn_updateLogFile();

print 'Script Finished.'

# end
