# Content :
Scripts to test how DNS respond to threats domains

# Use :
The DNS to test should be in a `.txt` file over the format :

`<DNS Server Address>` `<DNS Name>` `<options>`

To see which options are available, you can check the man page of `dig`

To launch the test; you should be in the root folder of this repository, and execute the script `dnsComparatorglobal.sh` with the name of your `.txt` file as argument

# Results :

The script will make the tests requests for you, and the results will be on a `results.txt` file.
You will see the number of blocked requests and the ratio
