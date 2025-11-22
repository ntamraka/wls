
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
        n = 4  # Updated to 9 panes
        server = libtmux.Server()
        session_name = "session_test"

        # Create a new session or find existing one
        session = server.new_session(session_name=session_name, kill_session=True, attach=False)
        session = server.find_where({"session_name": session_name})
        

        # Create a new window and panes
        window = session.new_window(attach=True, window_name=session_name)
       
        panes = [window.attached_pane] + [window.split_window(vertical=(i % 2 == 0)) for i in range(1, n)]
        emon = "python3 /root/tmc/tmc.py -u -n -x ntamraka -d /root/tmc/cassendra -G local -t 600  -i "+self.log_dir+" -a "+self.log_dir
        # List of 9 commands
        commands = [ 
            "numactl --physcpubind=0-35 /root/cass2/cass_0/bin/cassandra -R", 
            "numactl --physcpubind=36-71 /root/cass2/cass_1/bin/cassandra -R", 
            "numactl --physcpubind=72-107 /root/cass2/cass_2/bin/cassandra -R",
            "numactl --physcpubind=108-143 /root/cass2/cass_3/bin/cassandra -R"
            #"numactl --physcpubind=144-179 /root/cass2/cass_4/bin/cassandra -R", 
            #"numactl --physcpubind=180-215 /root/cass2/cass_5/bin/cassandra -R", 
            #"numactl --physcpubind=216-251 /root/cass2/cass_6/bin/cassandra -R",
            #"numactl --physcpubind=252-287 /root/cass2/cass_7/bin/cassandra -R",
            #"sleep 200; ./emon.sh "+self.log_dir+"_server"+str(n)
            ]
                    

        window.select_layout('tiled')

        # Send commands to panes

        for i, command in enumerate(commands * (n // len(commands))):
            panes[i].send_keys(command)

        # Additional commands
        #panes[0].send_keys('tmux kill-session -t session_test')
        server.attach_session(target_session=session_name)
        #window.kill_window()

if __name__ == "__main__":
    print(f"Using Automation version: {VERSION}")
    parser = argparse.ArgumentParser()
    parser.add_argument('-d', '--output_dir', type=str, default='./logs/', help="directory to save the log")
    args = parser.parse_args()

    automation = Automation(args)
    automation.date_logs()
    automation.run_session()

