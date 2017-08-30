mmm-agent
===========

This program is the agent part of MyMiners. It contacts 
myminers.net every few minutes to know what it should be
mining. Then, it starts the miner(s) and analyses its output to 
make sure everything is OK. 

If there is an issue (pool not responding, errors), it stops the 
miner and asks the server what to do next.

Once a mining run is done, it contacts the server, uploads the
logs (hashrates, clock frequencies, temperatures, fan speeds, 
power usage, etc...), and asks what to do next.

This program is opensource because we want you to be able to
check that we aren't doing anything evil. Trust does not replace
control, right? ;-) The server part is closed source because it
is our money maker. But the API is public so you can easily 
check it out...

Features
--------

* Runs miner instances in the background
* Monitors miner output to check everything is OK
* Monitors nvidia-smi output (temperatures, power usage, etc...)
* Uploads statistics to the server

Examples
--------

    mmm-agent --email <account-email> --token <account-token>

Requirements
------------

* Ruby 2.0 or higher
* nvidia-smi (gives the power consumption information that we need to calculate your most profitable mining option)
* Your miners compiled, accessible to the user running the agent, and named according to https://myminers.net/miner_releases

Miners have their own set of requirements, like the CUDA Toolkit,
but this is outside the scope of this documentation. You should
already have compiled your miners before you try to use MyMiners.

Install
-------

    cd /opt
    sudo git clone https://github.com/myminers/mmm-agent.git
    sudo cp mmm-agent/bin/mmm-agent.service /etc/systemd/system/mmm-agent.service
    sudo vi /etc/systemd/system/mmm-agent.service
    # Under 'User', set the system user you want to run the agent
    # Under 'ExecStart', set '/opt/mmm-agent/bin/mmm-agent --email <your account> --token <your api token>
    sudo systemctl enable mmm-agent
    sudo systemctl start mmm-agent

Update
------

The 'master' branch is the only one considered stable. Use other
branches at your own risks.

    cd /opt
    sudo git pull
    sudo systemctl restart mmm-agent

Author
------

Original author: MyMiners

Contributors:

* Your name goes here if you want to help improve the software ;-)

License
-------

(The MIT License)

Copyright (c) 2017 (MyMiners)

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
'Software'), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
