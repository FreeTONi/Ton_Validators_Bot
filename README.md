# Cloud bot for monitoring validators node. @TON_Validators_Bot

Hello everybody!

Monitoring is good. You can configure many different monitoring systems on your server where the validator's node is running. But what to do if the server crashes, freezes, something happened, the monitoring system is fail? You cannot track monitoring if it is unavailable or broken.

I propose a solution. My telegram bot [t.me/TON_Validators_Bot](http://t.me/TON_Validators_Bot) does not require installation on your server. It runs in my cloud and does not make any requests to your validator node. However, he can check the time when your node signed the last block in the blockchain. If your node does not sign new blocks for a long time, you will receive a notification in the telegram. You will immediately see that your server requires attention.

## What this bot can do?

####  Monitoring

 1. The bot periodically checks whether your validator node signs blocks.
 2. The bot checks to see if your validator is participating in future validator elections.
 3. The bot can automatically calculate your public keys and adnl addresses. It's comfortable.
 4. You can find out information about the validator without knowing its Account Address, just enter the public key or adnl address.

####  Alerts

 1. If for a long time there are no new signed blocks, you will receive a notification.
 2. If your node does not participate in future elections of validators, you will see it.

####  Functions

 1. Easy to use! The bot does not require you to take any steps to install and configure it. Just "/start" and enter your Account Address in hex.
 2. The bot does not interact with your server. It is completely autonomous.
 3. The bot checks the result of the validator, not the process. It is only important for him that the validator correctly signs the blocks and they are accepted by the network.
 4. The entire message history will be saved in the telegram chat history.
 5. Support for online monitoring of multiple addresses.
 6. The bot can update the last message, which shows monitoring of all addresses.

## Installation

 1. Create your personal telegram bot and get Api Token.
 2. Modify $bot_token = '1231231234:AAAABBBBCCCCDDDDEEEEFFFF00001111234'; 
 3. Install some perl modules 
 ```sh
perl -MCPAN -e 'install "WWW::Telegram::BotAPI Mojo::UserAgent HTTP::Request Digest::SHA qw(sha256_hex)"'
```
 4. Run bot: 
 ```sh 
perl ./bot-lite-client-version.pl
```
 5. Send to bot /start
 
## This bot is already running Telegram

 * In test mode on the network net.ton.dev [t.me/TON_Validators_Bot](http://t.me/TON_Validators_Bot) - just type "/start"
 * Sources are open
