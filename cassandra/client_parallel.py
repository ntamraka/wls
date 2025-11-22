import os
import argparse
import datetime
import libtmux

VERSION = 1.0

class Automation:

    def __init__(self, args):
        self.args = args
        self.output_dir = self.args.output_dir
        self.log_dir=""
        self.run_name=self.args.run_name
        self.threads=self.args.threads
        self.time=self.args.time


    def date_logs(self):
        x = datetime.datetime.now()       
        path = os.path.join(self.output_dir, datetime.datetime.now().strftime('%Y-%m-%d_%H-%M-%S'))
        self.log_dir = path       
        try:  
            os.makedirs(path) 
            print(f"{path} created for output logs")  
        except OSError as error:  
            print(f"{path} Directory already exists!!") 

    def run_session(self):
        print('-' * 80)  
        n = 4 # Updated to 9 panes
        server = libtmux.Server()
        session_name = "session_test"

        # Create a new session or find existing one
        session = server.new_session(session_name=session_name, kill_session=True, attach=False)
        session = server.find_where({"session_name": session_name})
        


        # Create a new window and panes
        window = session.new_window(attach=True, window_name=session_name)
        
        panes = [window.attached_pane] + [window.split_window(vertical=(i % 2 == 0)) for i in range(1, n)]

        emon = "python3 /root/tmc/tmc.py -u -n -x ntamraka -d /root/tmc/cassendra -G local -t 80  -i " +self.run_name+" -a "+self.run_name
        sleeptime = int(self.args.time) 
        # List of 9 commands
        
        commands = [
              
                    #"numactl --physcpubind=252-287 ./tools/bin/cassandra-stress user profile=./tools/cqlstress-insanity-example.yaml ops\(insert=20,simple1=80\) cl=ONE duration="+self.args.time+"s -mode native cql3 -pop dist=UNIFORM\(1..150m\) -node 10.75.119.35 -rate threads="+self.args.threads+" -errors ignore 2>&1 | tee "+self.log_dir+"/10.75.119.35.txt",
                    "numactl --physcpubind=144-179 -m 1 /root/cass2/cass_0/tools/bin/cassandra-stress user profile=/root/cass2/cass_0/tools/cqlstress-insanity-example.yaml ops\(insert=20,simple1=80\) cl=ONE duration="+self.args.time+"m -mode native cql3 connectionsPerHost=32 -pop dist=UNIFORM\(1..195m\) -node 10.75.119.33 -rate threads="+self.args.threads+" -errors ignore 2>&1 | tee "+self.log_dir+"/10.75.119.33.txt",
                    "numactl --physcpubind=180-215 -m 1 /root/cass2/cass_0/tools/bin/cassandra-stress user profile=/root/cass2/cass_0/tools/cqlstress-insanity-example.yaml ops\(insert=20,simple1=80\) cl=ONE duration="+self.args.time+"m -mode native cql3 connectionsPerHost=32 -pop dist=UNIFORM\(1..195m\) -node 10.75.119.34 -rate threads="+self.args.threads+" -errors ignore 2>&1 | tee "+self.log_dir+"/10.75.119.34.txt",
                    "numactl --physcpubind=216-251 -m 1 /root/cass2/cass_0/tools/bin/cassandra-stress user profile=/root/cass2/cass_0/tools/cqlstress-insanity-example.yaml ops\(insert=20,simple1=80\) cl=ONE duration="+self.args.time+"m -mode native cql3 connectionsPerHost=32 -pop dist=UNIFORM\(1..195m\) -node 10.75.119.35 -rate threads="+self.args.threads+" -errors ignore 2>&1 | tee "+self.log_dir+"/10.75.119.35.txt",
                    "numactl --physcpubind=252-287 -m 1 /root/cass2/cass_0/tools/bin/cassandra-stress user profile=/root/cass2/cass_0/tools/cqlstress-insanity-example.yaml ops\(insert=20,simple1=80\) cl=ONE duration="+self.args.time+"m -mode native cql3 connectionsPerHost=32 -pop dist=UNIFORM\(1..195m\) -node 10.75.119.36 -rate threads="+self.args.threads+" -errors ignore 2>&1 | tee "+self.log_dir+"/10.75.119.36.txt",

                    #"sleep 360 ; /root/cass2/emon.sh 180 "+self.run_name
                  ]
        

      

        window.select_layout('tiled')

        # Send commands to panes
        for i, command in enumerate(commands * (n // len(commands))):
            
            panes[i].send_keys(command)
           

        # Additional commands
        panes[0].send_keys("sleep 100")
        extract_results="python3 extracter.py -d "+self.log_dir+" -n "+self.run_name  
        panes[0].send_keys(extract_results)
        panes[0].send_keys("sleep 10")
        panes[0].send_keys('tmux kill-session -t session_test')
        server.attach_session(target_session=session_name)
        #window.kill_window()

if __name__ == "__main__":
    print(f"Using Automation version: {VERSION}")
    parser = argparse.ArgumentParser()
    parser.add_argument('-d', '--output_dir', type=str, default='./output/', help="directory to save the log")
    parser.add_argument('-n', '--run_name', type=str, default='test_run', help="directory to save the log")
    parser.add_argument('-t', '--threads', type=str, default=8, help="directory to save the log")
    parser.add_argument('-T', '--time', type=str, default=120, help="time in minute")

    args = parser.parse_args()

    automation = Automation(args)
    automation.date_logs()
    automation.run_session()
   
    

