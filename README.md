# HA-simple
An example of a HTTP website that is very simple, but HA and FT!
- running in the AWS Cloud,
- using AWS Managed Services,

## Documentation

# What else might I do with my website?

My thoughts first go to Security, Scalability and Redundancy.

Additional security could be incorporated in a build process. My current example relies on Canonical (Ubuntu) updating their AMIs every so often (I've not setup kernel live-patching), and I'm just running a simple `apt upgrade` command to bring the software up to date. Ideally I'd incorporate scanning of the current infrastructure (and report on the results), and use a build process that also reports, but also halts the build if issues of a certain severity or greater are encountered. I'm familiar with security scanning and a build process using ArgoCD that'd halt a deployment, but my goal with this repo/demo was to provide a 'proof of concept' that meets the requirements without being overly complicated. Simple is often best. I do realize I could have just hosted a static website in S3 [1], but I feel if I did that I really wouldn't be able to demonstrate 'much skill', or thought on what should be considered when you are designing a solution. The solution I provided provides a base that can be expanded upon to provide more features, and better Security, Scalability and Redundancy; if I chose the S3 option, and if extra functionality was desired, I'd then need to move the website to use a different solution.

Scalability, my solution provides limited scalability, principally because I've chosen to place a limit on the ASG (this is mainly to limit cost, if it does decide to scale up). And this is not to imply placing a limit on ASGs are bad, I'd actually argue this can be a good practice, you should know rougly how much your VMs will scale. AWS does run out of available VMs in certain Availability Zones, and for some Instance types this happens across the AWS Region. Ideally you'd have a plan to ensure capacity, eg. ODCR [2] or Zonal RIs [3].
After considering VM capacity and how much my web application needs to scale, another consideration for ensuring better scalability can be to have the web application scale in other Regions, and also to have it scale in different Cloud Providers. This provides flexibility, and it also provides additional contingency if there are any capacity issues; eg. if there was an issue in one Region, you can scale up in other Regions to compensate, and the same goes for Cloud Providers, if a Cloud Provider is experiencing an issue, you can scale up with your other Cloud Provider.
Another addition I'd make to my website (as a need to scale is identified) is to add a CDN (Content delivery network), although CDNs are becoming more feature rich, the main use of a CDN is delivering static content to end-users faster.
A final consideration for scalability is the use of Message Queues where appropriate. When message queues can replace load balancers this generally results in a more efficient use of compute resources (albeit it is not applicable everywhere).

Redundancy, this can often have some overlap with Scalability, but it also needs to be considered separately. For instance, it is possible to architect a solution that scales across Regions and Cloud Providers, but there could still be dependencies or possibly a 'single point of failure'. Part of Redundancy is ensuring there are no 'single points of failures'. This will often involves the use of health checks and automatic fail-overs, eg. having your DNS fail-over to direct all traffic to your operational Cloud Provider when a health check for one Cloud Provider fails.
Redundancy should also be considered at the data storage level. Data should be replicated across multiple sites, and ideally it would be replicated both across Region and across Cloud Providers. Consideration also needs to be given to how data is accessed, if a data store is offline for some reason, does the failover to another data source happen at the ASG level or higher, eg. route to a different Load Balancer that uses a different ASG, or would the Operating System on the VMs use a networked filesystem that has failover functionality. In my mind the solution you choose depends on the amount of data that needs to be accessible, and how you want to synchronize the data across all compute resources that needs to access the data. If a Database is a good solution for your data, then there are many patterns available for synchronizing your data, and scaling the databases. For some use-cases a Cloud Provider managed object storage solution like S3 might be a desirable and cost effective approach.


## References:
[1] https://docs.aws.amazon.com/AmazonS3/latest/userguide/WebsiteHosting.html 

[2] ODCR: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-capacity-reservations.html 

[3] Zonal RIs: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/reserved-instances-scope.html#reserved-instances-regional-zonal-differences 
