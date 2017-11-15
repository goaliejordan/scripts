#!/usr/bin/python
#
#  Query the VSP array using raidcom cmd and read in all ports, hosts, ldevs 
#     along with capacity information
#  Data is exported to a csv file
#  data is also exported to MySql db
#
# to run # vsp_query.py HDS_VSP_12345
# edit array_name for each script
#

import sys, subprocess, string, re, os, MySQLdb

# Global Variables
raidcom = '/HORCM/usr/bin/raidcom'
location = 'ALP'  
# Edit for each script ***
array_name = 'HDS_VSP_'  # 'vendor_model_serial' --> HDS_VSP_xxxx, HDS_HUS_xxxx, HDS_USPV_xxxx, HDS_HUSVM_xxxx, HDS_AMS_xxxx
database_name = 'storagedb'

horcm_inst = '100'

ports = []
hosts = []
port_temp = []
host_groups = []
active_ldevs = []


portname2wwn = []

iniator = []
lun_id = []
lun_capacity = []
lun_consumed = []
pool_id = 0

class PortObj(object):
   """__init__() functions the class constructor"""
   def __init__(self, name=None, wwn=None, hosts=[]):
      self.name = name
      self.wwn = wwn
      self.hosts = hosts

class HostObj(object):
   """__init__() functions the class constructor"""
   def __init__(self, gid=None, initiator=None, port=None, ldevs=[], ldev_details=[], hwwn=[]):
      self.gid = gid
      self.initiator = initiator
      self.port = port
      self.ldevs = ldevs
      self.ldev_details = ldev_details
      self.hwwn = hwwn

class LdevObj(object):
   """__init__() functions the class constructor"""
   def __init__(self, ldev=None, host_mode = None, capacity = None, ports = None, pool = None, consumed = None):
      self.ldev = ldev
      self.host_mode = host_mode
      self.capacity = capacity
      self.ports = ports
      self.pool = pool
      self.consumed = consumed


# main

array_sn = sys.argv[1]
table_name = array_name + array_sn 


# get ports
getPorts = subprocess.Popen(raidcom + ' get port -s ' + array_sn + ' -IM' + horcm_inst, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True)
output, err = getPorts.communicate()
port_temp = string.split(output)

for p in port_temp:  # create a list 'ports' of all the available ports
   if p.startswith('CL'):
      ports.append(PortObj(p))

#loop over ports list and read in the WWN
i = 22
for port in ports:
   port.wwn = port_temp[i]
   i = i + 12   # every 12 slots is the wwn from the screen output

#for port in ports:
   #print port.name + ',' + port.wwn

# read in host groups off the port list
for port in ports:
   #getHostGroups = subprocess.Popen(raidcom + ' get host_grp -port ' + str(port.name) + ' -s ' + array_sn, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True)
   #output, err = getHostGroups.communicate()
   getHostGroups = raidcom + ' get host_grp -port ' + str(port.name) + ' -s ' + array_sn + ' -IM' + horcm_inst
   output = os.popen(getHostGroups)
   port.hosts = []
   for line in output:
      line = line.strip()
      groupfields = line.split()
      port_temp = groupfields[0]
      GID = groupfields[1]
      initiator = groupfields[2]
      OS = groupfields[4]
      if re.search('\d+',GID):
        if int(GID) > 0:
           #print GID + ',' + initiator + ',' + port.name + ',' + port_temp
           if port_temp == port.name:
              port.hosts.append(HostObj(GID, initiator, port.name))

# read ldev's attached GID/host
for port in ports:
   for host in port.hosts:
      getLdev = raidcom + ' get lun -port ' + str(port.name) + '-' + str(host.gid) + ' -IM' + horcm_inst
      getHwwn = raidcom + ' get hba_wwn -port ' + str(port.name) + '-' + str(host.gid) + ' -IM' + horcm_inst
      output = os.popen(getLdev)
      outputHwwn = os.popen(getHwwn)
      host.ldevs = []
      host.hwwn = []
      x = 0

      for line in output:
         line = line.strip()
         groupfields = line.split()
         port_temp = groupfields[0]
         gid_temp = groupfields[1]
         hostmode = groupfields[2]
         ldev = groupfields[5]
         if re.search('\d+', ldev):
            if ldev != "LDEV":
               if gid_temp == host.gid:
                  host.ldevs.append(LdevObj(ldev))  #adds ldev dec # to list
                  getLdevDetails = subprocess.Popen(raidcom + ' get ldev -ldev_id ' + str(ldev) + ' -IM' + horcm_inst, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True)
                  output, err = getLdevDetails.communicate()
                  ldevdetails_temp = string.split(output)
                  #print ldev.num
                  capacity_location = ldevdetails_temp.index("VOL_Capacity(BLK)")  #search for vol capacity
                  capacity_location = int(capacity_location) + 2 # skip over : to get LDEV capacity in Blocks. returns index location of volume capacity
                  capacity = ldevdetails_temp[capacity_location]
                  capacity = round(float(capacity) / 2 / 1024 / 1024,2)  #convert block down to GB
                  try:  # thin image does not report Used_Block(BLK)
                     consumed_location = ldevdetails_temp.index("Used_Block(BLK)")
                     consumed_location = int(consumed_location) + 2 # skip over : to get used capacity in blocks
                     consumed = ldevdetails_temp[consumed_location]
                     consumed = round(float(consumed) / 2 / 1024 / 1024,2)
                  except ValueError:
                     consumed = 'TI'  #put TI in value to represent ThinImage device  TI does not report Used_Block
                  host.ldevs[x].capacity = capacity
                  host.ldevs[x].consumed = consumed

                  for line2 in outputHwwn:
                     line2 = line2.strip()
                     groupfields = line2.split()
                     hwwn_temp = groupfields[3]
                     if re.search('\d+', hwwn_temp):
                        if hwwn_temp != "HWWN":
                           host.hwwn.append(hwwn_temp)
                           #print host.hwwn
                  x = x + 1




# establish DB connection
db = MySQLdb.connect(host="1.1.1.1", user="root", passwd="Pa55word", db=database_name)
insert_prefex = ("INSERT INTO %s " % (table_name)) 
insert = (insert_prefex + "(ldev_number, ldev_allocated, ldev_consumed, array_sn, location) VALUES (%s, %s, %s, %s, %s)")
cursor = db.cursor()

# check if tables exists if so drop it if not create new table.
read_tables = ("SHOW TABLES LIKE '%s'; " % (table_name))
cursor.execute(read_tables)
result = cursor.fetchone()
if result:
   # if table exists drop it
   cursor.execute("drop TABLE %s; " % (table_name))
#  no table exists create new primary table for array
cursor.execute("""CREATE TABLE %s(
ldev_number INT NOT NULL, 
ldev_allocated varchar (255),
ldev_consumed varchar(255),
array_sn varchar(255),
location varchar(255),
PRIMARY KEY (ldev_number));
""" %(table_name))

file = open("HDS_VSP_" + array_sn + ".csv", "w")
#write cvs header
file.write('host_group_name' + ':' + 'port' + ':' + 'wwn' + ':' + 'ldev#(dec)' + ':' + 'ldev_capacity_GB' + ':' + 'ldev_consumed_GB\n')

# dump data to cvs file
for port in ports:
   for host in port.hosts:
     for ldev in host.ldevs:
        file.write(host.initiator + ':' + port.name + ':' + str(host.hwwn) + ':' + ldev.ldev + ':' + str(ldev.capacity) + ':' + str(ldev.consumed) + '\n')
        data = (ldev.ldev, ldev.capacity, ldev.consumed, array_sn, location)
        try:
           cursor.execute(insert, data)  # send data to MySQL
        except MySQLdb.Error, e:
           try:
              pass #print "MySQL Error [%d]: %s" % (e.args[0], e.args[1])
           except IndexError:
              pass #print "MySQL Error: %s" % str(e)
        else:
           pass  # don't do anything

cursor.close()
file.close()

#end