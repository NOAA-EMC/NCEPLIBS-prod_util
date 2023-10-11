#!/usr/bin/env python3

# Author:  Kit Menlove <kit.menlove@noaa.gov>
#	   Edits by <Arash.Bigdeli@noaa.gov> 2021 Aug
# Purpose: If the user is in the prod group, submit and send an e-mail message
#          For other users, the message is merely printed to standard out.
# Usage:   mail.py -s subject [-c cc-addr] [-b bcc-addr] [--html] [-v] to-addr message_file
#          mail.py -s subject [-c cc-addr] [-b bcc-addr] [--html] [-v] [to-addr] < message_file
#          echo "$msg" | mail.py -s subject [-c cc-addr] [-b bcc-addr] [--html] [-v] [to-addr]
# Input:   message_file - a text file with the body of the message
#          to-addr - a comma-delimited list of recipient e-mail addresses

from __future__ import print_function
from os import getenv, getuid, path, environ, system
import re, grp, pwd
import fileinput
from subprocess import check_output, call
from email.utils import formatdate
from sys import exit, stderr
from email.mime.text import MIMEText
from time import sleep, time

# prod jobs go to the prod database, everything else goes to the para database
envir = getenv('envir')
PARATEST = getenv('PARATEST')
model = getenv('model')
current_user=pwd.getpwuid(getuid())[0]
current_user_address=('nco.spa' if current_user in ("ops.para" "ops.prod") else current_user) + '@noaa.gov'
default_recipient=(getenv('MAILTO') if getenv('MAILTO') else current_user_address)

email_regex=r"[a-zA-Z][-+._%a-zA-Z0-9]*@[a-zA-Z0-9]+(?:[-.][a-zA-Z0-9]+){0,12}\.[a-zA-Z]{2,15}"
def validate_email_address_list(raw_address):
    address = re.sub(r"\s+", '', raw_address)
    match_result = re.match(r"{e}(?:,{e})*$".format(e=email_regex), address)
    if not match_result:
        raise ValueError('{0} does not contain a list of valid email addresses'.format(address))
    return address

def send(subject, message_body, to_address=default_recipient, cc_address=None, bcc_address=None, from_name=None, is_html=False, verbose=False):
    # Generate the "from" address
    from_address = current_user_address
    # Prepend the environment to the subject if not "prod"
    if envir == 'prod' or envir == None:
        if PARATEST == 'YES':
            message_subject = ("[{0}] {1}".format("PARATEST", subject.strip()))
        else:
            message_subject = ("[{0}] {1}".format("WCOSS2", subject.strip()))
    else:
        if PARATEST == 'YES':
            message_subject = ("[{0}-{1}] {2}".format("PARATEST", envir, subject.strip()))
        else:
            message_subject = ("[{0}] [{1}] {2}".format("WCOSS2",envir, subject.strip()))
    # If certain job-information variables are set, create a string containing their values to append to the message
    job_info = []

    ecFlow_task_path = getenv('ECF_NAME')
    if ecFlow_task_path:
        job_info.append(("ecFlow Task", ecFlow_task_path))
    if getenv('ECF_RID'):
        try:
            stdout_file = check_output("qstat -fwx {0} | grep Output_Path".format(getenv('ECF_RID')), shell=True).decode().split(":")[1]
        except:
            stdout_file="Job ran locally"
        finally:
            job_info.append(("Standard Output", stdout_file))
    if job_info:
        job_info_text = '<br /><hr /><table>' if is_html else "\n{0}\n".format('-'*80)
        for info in job_info:
            if is_html:
                job_info_text += "<tr><td><b>{0}</b>:</td><td style=\"padding-left:3px\">{1}</td></tr>".format(*info)
            else:
                job_info_text += info[0] + ": " + info[1] + "\n"
        if is_html:
            job_info_text += "</table>"
    else:
        job_info_text = ""

    # Make sure html messages are wrapped in <html></html> tags
    # TODO: Do we need to validate or encode the message body?  Make sure it isn't too long or contains characters that would mess up the query?
    if is_html:
        if re.match(r"\s*<html", message_body, re.IGNORECASE):
            message_body = re.sub(r"(?i)(</body|</html)", r"{0}\1".format(job_info_text), message_body, 1)
        else:
            message_body = '<html><body>' + message_body.strip() + job_info_text + '</body></html>'
    else:
        message_body += job_info_text

    message_info = {
        "timestamp": formatdate(),
        "target_address": to_address,
        "carbon_copy_address": cc_address,
        "blind_carbon_copy_address": bcc_address,
        "from_name": from_name,
        "from_address": from_address,
        "reply_to": current_user_address,
        "message_subject": message_subject,
        "body": message_body,
        "is_html": is_html
    }
    if current_user in grp.getgrnam("ops").gr_mem:
       print(message_info)
       msg = MIMEText(message_info['body'], ('html' if message_info['is_html'] else 'plain'))
       msg['Date'] = message_info['timestamp']
       if message_info['from_name']:
           msg['From'] = "{0} <{1}>".format(message_info['from_name'], message_info['from_address'])
       else:
           msg['From'] = message_info['from_address']
       msg['reply_to'] = message_info['reply_to']
       msg['To'] = message_info['target_address']
       msg['Cc'] = message_info['carbon_copy_address']
       msg['Subject'] = message_info['message_subject']
       all_recipients = message_info['target_address'].split(',')
       if isinstance(message_info['carbon_copy_address'], str): all_recipients.extend(message_info['carbon_copy_address'].split(','))
       if isinstance(message_info['blind_carbon_copy_address'], str): all_recipients.extend(message_info['blind_carbon_copy_address'].split(','))
       
       verbose=True
       if msg['Cc']:  
         errors = system('echo "%s" | mailx -s "%s" -c %s %s -r %s' %(message_info['body'],msg['Subject'],msg['Cc'],msg['To'],msg['reply_to']))
       else:
         errors = system('echo "%s" | mailx -s "%s" %s -r %s' %(message_info['body'],msg['Subject'],msg['To'],msg['reply_to']))

       if errors:
           print("Unable to deliver to one or more recipients:", errors, file=stderr)
           exit(1)
    else:
        print('The following message will NOT be sent due to insufficient permissions:')
        verbose=True

    # Print the email to stdout if verbose flag is set or the user is not in the prod group
    if verbose:
        print('-'*80)
        print("To: %(target_address)s" % message_info)
        if message_info['from_name']:
            print("From: \"%(from_name)s\" <%(from_address)s>" % message_info)
        else:
            print("From: %(from_address)s" % message_info)
        print("""Date: %(timestamp)s
Subject: %(message_subject)s
%(body)s
--------------------------------------------------------------------------------""" % message_info)

if __name__ == "__main__":
    import argparse

    def EmailType(raw_address):
        try:
            address_list = validate_email_address_list(raw_address)
            if not address_list:
                raise argparse.ArgumentTypeError('One or more addresses were invalid')
            return address_list
        except ValueError:
            raise argparse.ArgumentTypeError('%s is not a valid address list' % raw_address)

    # Parse command line arguments
    parser = argparse.ArgumentParser(description='Submit an e-mail message to the production e-mail queue to be transmitted by the jsendmail job.  The message body may be piped via stdin or provided as an input file (i.e. message_file) following the recipient list.',
        usage='''echo "$msg" | %(prog)s -s subject [-c cc-addr] [-b bcc-addr] [--html] [-v] [to-addr]
usage: %(prog)s -s subject [-c cc-addr] [-b bcc-addr] [--html] [-v] to-addr message_file
usage: %(prog)s -s subject [-c cc-addr] [-b bcc-addr] [--html] [-v] [to-addr] < message_file''')
    # Subject is optional when $jobid variable is set
    if getenv('jobid'):
        parser.add_argument('-s', '--subject', default="Message from WCOSS2 job " + getenv('jobid'), metavar='subject', help="subject of the e-mail message")
    else:
        parser.add_argument('-s', '--subject', required=True, metavar='subject', help="subject of the e-mail message")
    parser.add_argument('-c', '--cc', type=EmailType, metavar='cc-addr', help='comma-delimited list of carbon copy recipient(s)')
    parser.add_argument('-b', '--bcc', type=EmailType, metavar='bcc-addr', help='comma-delimited list of blind carbon copy recipient(s)')
    parser.add_argument('-n', '--from', dest='from_name', metavar='name', help='name or title of the sender - will not change the underlying address')
    parser.add_argument('-v', '--verbose', action='store_true', help='print the message header and body')
    # Default "to" address to user's NOAA inbox (or SPA helpdesk when user is ops.prod)
    parser.add_argument('address', default=default_recipient, nargs='?', type=EmailType, metavar='to-addr',
        help='comma-delimited e-mail address(es) of the intended recipient(s); if omitted, the message will be sent ' +
        'to the recipient(s) specified in the $MAILTO variable, or the current user @noaa.gov if undefined')
    parser.add_argument('--html', action='store_true', help='send the message as HyperText Markup Language (HTML)')
    (args, message) = parser.parse_known_args()

    message_body = ''.join(fileinput.input(message))
    send(args.subject, message_body, args.address, args.cc, args.bcc, args.from_name, args.html, args.verbose)
    sleep(2)
