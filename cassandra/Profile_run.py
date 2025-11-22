import os
import argparse
import datetime
import libtmux
import time

VERSION = 1.0

class Automation:

    def __init__(self, args):
        self.args = args
        self.output_dir = self.args.output_dir
        self.run_name=self.args.run_name
        self.time=self.args.time
        self.log_dir=""
        

    def date_logs(self):
        x = datetime.datetime.now().strftime('%Y-%m-%d_%H-%M-%S')     
        self.run_name=self.run_name+"_"+x
        path = os.path.join(self.output_dir, self.run_name)
        self.log_dir = path       
        try:  
            os.makedirs(path) 
            print(f"{path} created for output logs")  
        except OSError as error:  
            print(f"{path} Directory already exists!!") 

    def run_session(self):
        print('-' * 80)  
        n = 5  # Updated to 9 panes
        server = libtmux.Server()
        session_name = "profile_session"
        print("Sleeping for few sec ...")
        time.sleep(5)

        # Create a new session or find existing one
        session = server.new_session(session_name=session_name, kill_session=True, attach=False)
        session = server.find_where({"session_name": session_name})
        

        # Create a new window and panes
        window = session.new_window(attach=True, window_name=session_name)
       
        panes = [window.attached_pane] + [window.split_window(vertical=(i % 2 == 0)) for i in range(1, n)]
        sleeptime=self.time*5
    
              
        commands = [ 
            "./emon.sh "+str(sleeptime)+" "+self.log_dir+"_server"+str(n),
            "sar -n DEV 5 "+ str(self.time)+" 2>&1 | tee "+self.log_dir+"/network_stat.txt", 
            "iostat -xd -y 5 "+ str(self.time)+" 2>&1 | tee "+self.log_dir+"/io_stat.txt", 
            "mpstat -N 0-1 5 "+ str(self.time)+" 2>&1 | tee "+self.log_dir+"/mp-stat.txt",
            "htop"
            ]
                    

        window.select_layout('tiled')

        # Send commands to panes

        for i, command in enumerate(commands * (n // len(commands))):
            panes[i].send_keys(command)

        # Additional commands
        panes[0].send_keys('sleep 60')
        panes[0].send_keys('tmux kill-session -t profile_session')
        
        server.attach_session(target_session=session_name)
        #window.kill_window()
        print("Please check the logs at: ", self.log_dir)

if __name__ == "__main__":
    print(f"Using Automation version: {VERSION}")
    parser = argparse.ArgumentParser()
    parser.add_argument('-d', '--output_dir', type=str, default='./Profile_logs/', help="directory to save the log")
    parser.add_argument('-n', '--run_name', type=str, default='test_run', help="directory to save the log")
    parser.add_argument('-t', '--time', type=int, default=10, help="give time in multiple of 5*X")
    args = parser.parse_args()

    automation = Automation(args)
    automation.date_logs()
    automation.run_session()

