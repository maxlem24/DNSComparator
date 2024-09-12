# Goal :

The goal of this project is to test the blockrate of the DNS solution you use in your company

# Usage :

-l filename : Set the list of DNS to test **required**. The format is `ServerAddress Name Options`. 
Options are used for DNS-Over-Https, with `ServerAddress` the domain and `Options` the path, beginning with `/`

-b filename : Set the list of the blockpages IP adresses **required**
You will find the blockpages addresses in the settings of your DNS Provider. You can also run a first time the app, and check in the verbose folder which address at more frequent that the others.

-d filename : Set the list of domains to test. *Default: valid.txt* 

-f : Force the use of the list of domains if it is been updated since more than 24 hours

-h : Display the use of the command

-y : Accept that the data collected will be sent to Kappa Data

# Results :

In the file `results.txt`, you will find the blockrate of each solution tested. A `verbose` folder is also create, with the list of timed-out and non-blocked address for each solution.
