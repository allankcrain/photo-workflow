# photo-workflow
Personal scripts for managing my photography workflow.

These scripts are all very specific to my personal workflow for copying and
storing the photos I take, so they probably won't be particularly useful to
anyone else. On the off chance they are, though, consider them GPL'd. The main
reasons I'm keeping them on Github is for my own personal backup (I just had
to rewrite all of these due to an SSD failure) and as an example for any
potential employers of the way I tend to write code that I don't actually
intend to be seen or used by anyone but myself.

## cameramaint

My script for copying photos/videos off of memory cards, written in ruby.

A brief outline of how this script works:

* Get all memory cards mounted under the /media directory
* Gets all photo/video files on the cards
* Sorts by time
* Copies them into the appropriate day-specific directory for when they were taken on the main RAID
* Moves them into the appropriate day-specific directory on the backup RAID

It should be smart enough to automatically prevent itself from clobbering an
existing file by checking the filename and adding an incremental suffix if it
already exists in the destination directory.

It's also smart enough to group photos by logical day instead of by raw
timestamp--I.e., if I was shooting at 11:59pm and still shooting right after
midnight, it doesn't put the files from after midnight in a new day directory.
It only moves on to the new day directory if there's a gap of more than four
hours between files. As of this version, it's also smart enough to recognize
when there's an existing directory that I thought I was already done with
(I.e., it's named with a description after the ISO8601 date, and possibly moved
underneath the year directory).

## dante-backup

Simple shell script to call rsync to keep everything on the backup RAID in
sync with the main RAID. Maintains quick little sanity-check files on each
RAID so it doesn't accidentally try to delete my whole backup RAID if the
main RAID isn't mounted, or accidentally try to several TB to my internal SSD
if the backup RAID isn't mounted.

## whatdayis

I've been taking photos every single day for over a decade now. When I upload
them to Flickr, I title that day's photo with "Day XXX", starting from my
birthday that year. I used to just count from the previous day I'd uploaded,
but that lead to a lot of human error when I forgot days or double-counted a
day or whatever. So I wrote myself a script to automatically calculate what
day of a photo year a given date is. E.g., 2020-10-20 will be day 1 for that
photo year, 2020-10-21 is day 2, etc. The very first photo of the day was on
2007-10-20, so it also counts the number of days since then so I can marvel at
how long I've kept it up.
