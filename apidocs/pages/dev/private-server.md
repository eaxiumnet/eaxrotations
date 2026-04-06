# Private Server Guide | Project Sylvanas

Source: https://docs.project-sylvanas.net/dev/private-server

## Overview

⭐ Getting started
Private Servers

## How to Use PS with Private Servers

This guide explains how to use Project Sylvanas (PS) with private servers, including our Community Private Server hosted for testing and development purposes.

### Why Use a Private Server?​

Private servers are perfect for testing your plugins and rotations:

⚡ Instant leveling - Skip the grind and test at any level

🗺️ Instant travel - Teleport anywhere without wasting time

🎯 Target dummies - Test DPS and rotations efficiently

👥 Bot parties - Run dungeons and raids with AI companions

🛡️ Instant gear - Equip BiS items for any bracket instantly

📚 All spells - Learn every spell without training

💰 Free to use - No subscription required

This is especially valuable for WoW Classic where leveling is slow and traveling takes forever. Save hours of testing time!

### Community Private Server​

We maintain a Community Private Server for PS users, hosted by PekingEnte.

#### Supported Versions​

VersionExpansionPatchVanillaClassic1.12TBCThe Burning Crusade2.4

#### Server Features​

Our community server comes with many quality-of-life features:

🤖 Bot companions for dungeons and raids

🎯 Target dummies everywhere for testing

🚕 Custom taxi NPCs with useful scripts:

Instant equip BiS items for many bracket levels

Teach all spells instantly

Level adjustment

And more...

#### Getting an Account​

To get an account on the Community Private Server:

Contact PekingEnte on Discord

Discord Username: .mydayyy

Request an account for Vanilla, TBC, or both

Community Support
PekingEnte is happy to help with questions about the private server setup. Don't hesitate to reach out!

### Quick Start - Community Server​

If you just want to connect to our Community Private Server, follow these steps:

#### Step 1: Download the Pre-Configured Client​

Vanilla 1.12:

```
https://drive.google.com/file/d/1IAzFS4_Pex7N-uP-dZ90SvS8T5EMn-2i/view?usp=sharing
```

TBC 2.4:

```
https://drive.google.com/file/d/16OHt64nzE-TwekiNDartR_GmQByI-_h6/view?usp=sharing
```

#### Step 2: Get an Account​

Contact PekingEnte (Discord: .mydayyy) to request an account.

#### Step 3: Launch and Play​

Extract the downloaded client

Run Start WoW Vanilla.cmd or Start WoW TBC.cmd

Login with your account credentials

You're ready to test!

Pre-Configured
These clients are already configured to connect to the Community Private Server. No additional setup required!

### Advanced - Running Your Own Server​

If you prefer to run your own local server instead of using the Community Server, follow these instructions.

#### Step 1: Download a WoW Repack​

A "repack" is a pre-configured server package that runs on your local machine.

Vanilla 1.12 Repack:

```
https://mega.nz/file/HMU03IZJ#rHFo1hdT05f9xgWWcu9qdbAeX_nr4EkcCqTqEzD-W18
```

TBC 2.4 Repack:

```
https://mega.nz/file/vV0BxSbT#hxlQ3edutb6cyIVySXjntR-tWKWMrfWIxtzR1HrLmCo
```

#### Step 2: Start the Repack Server​

Extract the repack to a folder

Run the server executable (usually start.bat or similar)

Wait for the world server to fully load

#### Step 3: Configure HermesProxy​

You need to modify the HermesProxy configuration to point to your local server.

Config file location:

```
World of Warcraft TBC\Hermes Launcher\hermes_proxy\HermesProxy.config
```

Change the server address:

Find this line:

```
<add key="ServerAddress" value="maste.me" />
```

Change it to:

```
<add key="ServerAddress" value="127.0.0.1" />
```

#### Step 4: Check the Port​

Port Configuration
This is a common issue! Make sure the port matches your repack's auth server port.

Find this line in the config:

```
<add key="ServerPort" value="3725" />
```

Default auth port is usually 3724, but the pre-configured clients use 3725 because the Community Server runs multiple realms.

If connecting to a local repack, you may need to change it to:

```
<add key="ServerPort" value="3724" />
```

Check your repack's configuration to confirm the correct auth port.

#### Step 5: Launch and Connect​

Run Start WoW TBC.cmd (or Vanilla equivalent) from the client folder

Login with the default repack credentials: admin / admin

You're connected to your local server!

#### Community Server (Default)​

SettingValueServerAddressmaste.meServerPort3725AccountRequest from PekingEnte

#### Local Server (Localhost)​

SettingValueServerAddress127.0.0.1ServerPort3724 (check your repack)Accountadmin / admin

#### "Unable to connect to server"​

Check ServerAddress - Is it maste.me (community) or 127.0.0.1 (local)?

Check ServerPort - Community uses 3725, local usually uses 3724

Firewall - Make sure the port isn't blocked

Server running - If local, ensure the repack server is fully started

#### "Invalid account or password"​

Community Server: Contact PekingEnte for valid credentials

Local Server: Default is usually admin / admin

#### "World server is down"​

Wait for the repack's world server to fully initialize

Check the server console for errors

Some repacks take a few minutes to load all maps

#### Pre-Configured Clients (Community Server)​

VersionLinkVanilla 1.12Google DriveTBC 2.4Google Drive

#### Server Repacks (Localhost)​

VersionLinkVanilla 1.12MEGATBC 2.4MEGA

### Tips​

Use Community Server First
We recommend starting with the Community Private Server. It's already configured, has useful QoL features, and PekingEnte can help if you have issues. Only set up a local server if you have specific needs.

Testing Workflow

Develop and test basic functionality on the private server

Use instant leveling and gear to test at different levels

Test edge cases with bot parties in dungeons

Final validation on retail/official servers

No Modifications Needed
The pre-configured clients from Google Drive are ready to use immediately. All the configuration instructions above are only for those who want to connect to their own local server instead.

### Contact​

Community Server Host: PekingEnte

Discord Username: .mydayyy

Feel free to reach out for:

Account requests

Server questions

Technical support

Feature requests

Happy testing! 🎮

Previous
Developer Program
Next
External Libraries

Why Use a Private Server?
Community Private ServerSupported Versions
Server Features
Getting an Account

Quick Start - Community ServerStep 1: Download the Pre-Configured Client
Step 2: Get an Account
Step 3: Launch and Play

Advanced - Running Your Own ServerStep 1: Download a WoW Repack
Step 2: Start the Repack Server
Step 3: Configure HermesProxy
Step 4: Check the Port
Step 5: Launch and Connect

Configuration SummaryCommunity Server (Default)
Local Server (Localhost)

Troubleshooting"Unable to connect to server"
"Invalid account or password"
"World server is down"

Downloads SummaryPre-Configured Clients (Community Server)
Server Repacks (Localhost)

Tips
Contact
