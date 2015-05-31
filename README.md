KeyBox as Code
==============

Repository with almost-automatic configuration of my desktops, laptops, etc.

Install dependencies
--------------------

Install python modules:

  virtualenv .env # lets use virtualenv
  . .env/bin/activate
  pip install -r requirements.txt

Install ansible submodules:

  ansible-galaxy install --force -r dependencies.yml

Tips
----

To see all the predefined variables in ansible:

  ansible -m setup keytocho -vvvv -u root
