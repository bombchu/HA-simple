# HA-simple
An example of a HTTP website that is very simple, but HA and FT!
- running in the AWS Cloud,
- using AWS Managed Services,

## Documentation

### Question: "What else you would do with your website, and how you would go about doing it if you had more time?"

Answer: My thoughts first go to Security, Scalability and Redundancy.

Additional security could be incorporated in a build process. My current example relies on Canonical (Ubuntu) updating their AMIs every so often (I've not setup kernel live-patching), and I'm just running a simple `apt upgrade` command to bring the software up to date. Ideally I'd incorporate scanning of the current infrastructure (and report on the results), and a build process that also reports but also halts the build if a certain severity issue is present. I'm familiar with security scanning and a build process using ArgoCD that'd halt a deployment, but my goal with this repo/demo was to provide a 'proof of concept' that meets the requirements without being overly complicated. Simple is often best. I do realize I could have just hosted a static website in S3 [1], but I feel if I did that I really wouldn't be able to demonstrate 'much skill', or thought on what should be considered when you are designing a solution. The solution I provided provides a base that can be expanded upon to provide more features, and better Security, Scalability and Redundancy; if I chose the S3 option, as soon as extra functionality was desired I'd need to move the website to use a different solution.

Scalability, my solution provides limited scalability, principally because I've chosen to place a limit on the ASG (this is mainly to limit cost; if it does decide to scale up). And this is not to imply placing a limit on ASGs are bad, I'd actually argue this can be a good practice, you should know rougly how much your VMs will scale. AWS does run out of available VMs in certain Availability Zones, and for some Instance types this happens across the AWS Region. Ideally you'd have a plan to ensure capacity, eg. ODCR [2] or Zonal RIs [3].
After considering VM capacity and how much my web application needs to scale, another consideration for ensuring better scalability can be to have the web application scale in other Regions, and also to have it scale in different Cloud Providers. This provides flexibility, and it also provides additional contingency if there are any capacity issues; eg. if there was an issue in one Region, you can scale up in other Regions to compensate, and the same goes for Cloud Providers, if a Cloud Provider is experiencing and issue, you can scale up with your other Cloud Provider.




## References:
[1] https://docs.aws.amazon.com/AmazonS3/latest/userguide/WebsiteHosting.html
[2] ODCR: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-capacity-reservations.html
[3] Zonal RIs: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/reserved-instances-scope.html#reserved-instances-regional-zonal-differences
