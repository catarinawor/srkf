#=================================================================
#Simple fit exploration of SR data
#Author: Catarina Wor
#Date: April 10th 2018
#=================================================================

#load in required packages and libraries

library(ggplot2)
library(TMB)
library(bayesplot)
library(tmbstan)
library(reshape)
library(xtable)
library(TMBhelper)

#load in directories.R
#set to current directory instead
#source("C:/Users/worc/Documents/HarrisonSR/R/directories.R")
#source("/Users/catarinawor/Documents/work/Chinook/srkf/R/directories.R")

#setwd(model_dir)
source("calc_quantile.R")
source("TMB_functions.R")

#read in simple data set
SR <- read.csv("../data/Harrison_simples_Apr18.csv")

iteracs=100000
# LM version
#simple model

srm<-lm(log(SR$R/SR$S_adj)~ SR$S_adj)
a_srm<-srm$coefficients[1]
b_srm<--srm$coefficients[2]
alpha<-exp(a_srm)

u_msy=.5*a_srm-0.07*a_srm^2
predR1<- SR$S_adj*exp(a_srm-b_srm*SR$S_adj)

mydata<-list(obs_logR=log(SR$R),obs_S=SR$S_adj)
parameters_simple <- list(
  alpha=(a_srm),
  logbeta = log(b_srm),
  logSigObs= log(.4)  )

simpl<-list(
  dat=mydata,
  params=parameters_simple,
  rndm=NULL,
  dll="Ricker_simple",
  DIR="."
  )

simple <- runTMB(simpl)

simple$opt
TMBAIC(simple$opt) #77.57106

TMBAIC(recursivep2$opt)-TMBAIC(simple$opt)

2*3-2*-35.78553

simpleobj <- simple$obj

simpleobj$report()


#diagnosticts
qqnorm(simpleobj$report()$residuals)
abline(0,1)


#MCMC
simpleB<-list(
  obj=simpleobj,
  nchain=3,
  iter=iteracs,
  lowbd=c(0.1,-13.5,-6.0),
  hibd=c(4.0,-8.5,5.0)
)

posterior_simple<-posteriorsdf(simpleB)

#plots
#plot_posteriors(posterior_simple$posteriors)
#posteriors of derived quantities -- the interesting ones
simpdf <- posterior_simple$posteriors


a<-(simpdf$value[simpdf$parameters=="alpha"])
alpha<-exp(simpdf$value[simpdf$parameters=="alpha"])
beta<-exp(simpdf$value[simpdf$parameters=="logbeta"])
Smax<-1/exp(simpdf$value[simpdf$parameters=="logbeta"])
sig<-exp(simpdf$value[simpdf$parameters=="logSigObs"])
umsy_simple<-.5*a-0.07*a^2

deriv_posteriors<-data.frame(chains=rep(simpdf$chains[simpdf$parameters=="logbeta"],4),
                             parameters = rep(c("a","b","S[max]","sigma"),each=length(a)),
                             value = c(a,beta,Smax,sig)
                             )

pm <- ggplot(deriv_posteriors)
pm <- pm + geom_density(aes(x=value, color=chains), size=1.2)
pm <- pm + facet_wrap(~parameters, scales="free",
  labeller = label_parsed)
pm <- pm + theme_bw(16)+labs(colour = "Prior", x="Value", y="Density")
pm <- pm + scale_color_viridis_d(end = 0.8,option = "A")

pm
ggsave("../figs/posterior_simple_model_fit.pdf", plot=pm, width=10,height=7)

#pm <- pm + scale_x_discrete(
#               labels = c(expression(a),expression(b),
#                expression(sigma),expression(S_max)))
#print(pm)



Rprdbsimple<-matrix(NA,ncol=length(SR$BroodYear),nrow=length(sig))

meanRsimple<-NULL

varRsimple<-NULL


for(i in 1:length(sig)){

  Rprdbsimple[i,]<-as.numeric(SR$S_adj*exp(a[i])*exp(-SR$S_adj* beta[i]))
  
  meanRsimple[i]<-mean(Rprdbsimple[i,]/SR$R) 

  varRsimple[i]<-var(Rprdbsimple[i,]/SR$R)

}


#=============================================================================================================
#Recursive Bayes model - and prior sensitivity

#priors

x=seq(0,1,0.05)
pr1 <- dbeta(x,1,1)
pr2 <- dbeta(x,3,3)
pr3 <- dbeta(x,2,3)
pr4 <- dbeta(x,3,2)
pr4 <- dbeta(x,4,2)
#
dfpr<-data.frame(x=rep(x,4),val=c(pr1,pr2,pr3,pr4),
  type=rep(c("uninformative 1, 1"," base 3, 3","low obs 2, 3","high obs 3, 2"),each=length(x)))
#
pr<-ggplot(dfpr,aes(x=x,y=val, col=type))
pr<-pr+geom_line(size=2)
pr<-pr+ylab("density")+xlab(expression(paste(rho," range")))
pr<-pr +theme_bw(16)+labs(colour = "Prior")
pr<-pr+facet_wrap(~type) + scale_color_viridis_d(end = 0.8)
pr
ggsave("../figs/priors_Rho.pdf", plot=pr, width=10,height=7)


#===========================================================
#mcmc

# uninformative scenario

parameters_recursive <- list(
  alphao=a_srm,
  logbeta = log(b_srm),
  rho=.2,
  logvarphi= 0.1,
  alpha=rep(0.9,length(SR$R))
  )


mydata1<-list(obs_logR=log(SR$R),obs_S=SR$S_adj,prbeta1=1.0,prbeta2=1.0)

recursive1<-list(
  dat=mydata1,
  params=parameters_recursive,
  rndm="alpha",
  dll="Rickerkf_ratiovar",
  DIR="."
  )


recursive1<-runTMB(recursive1, comps=TRUE)
recursive1$opt
recursiveobj1<-recursive1$obj

repkf1<-recursiveobj1$report()

recursiveB1<-list(
  obj=recursiveobj1,
  nchain=3,
  iter=iteracs,
  lowbd=c(0.1,-13.5,0.0,-3.0),
  hibd=c(4.0,-9.,1.0,5.0)
)


posterior_recursive1<-posteriorsdf(recursiveB1)

recrsdf1<-posterior_recursive1$posteriors

a_rb1<-(recrsdf1$value[recrsdf1$parameters=="alphao"])
beta_rb1<-exp(recrsdf1$value[recrsdf1$parameters=="logbeta"])
Smax_rb1<-1/exp(recrsdf1$value[recrsdf1$parameters=="logbeta"])
rho_rb1<-(recrsdf1$value[recrsdf1$parameters=="rho"])
umsy_rb1<-.5*a_rb1-0.07*a_rb1^2


soa1<-recrsdf1[grep("alpha",recrsdf1$parameters),]
summary(soa1)
soa1$umsy <- .5*soa1$value-0.07*soa1$value^2
umsyposteriorsummary1 <- aggregate(soa1$umsy,list(soa1$parameters),function(x){quantile(x,probs=c(0.025,.5,.975))})
umsyposteriorsummary1<-umsyposteriorsummary1[c(1,12,23,25:30,2:11,13:22,24),]




rhodf1<-recrsdf1[recrsdf1$parameters=="rho",]
rhodf1t<-rhodf1
rhodf1t$value<-rbeta(nrow(rhodf1),1,1)
rhodf1p<-rbind(rhodf1,rhodf1t)
rhodf1p$distribution<-rep(c("posterior","prior"),each=nrow(rhodf1))
rhodf1p$scn<-"uninformative 1, 1"



#deriv_posteriors1<-data.frame(chains=rep(recrsdf1$chains[recrsdf1$parameters=="logbeta"],5),
#                             parameters = rep(c("ao","b","Smax","rho","umsy"),each=length(a_rb1)),
#                             value = c(a_rb1,beta_rb1,Smax_rb1,rho_rb1,umsy_rb1)
#                             )
#plot_posteriors(deriv_posteriors1,salvar=FALSE,DIR=figs_dir,nome="posterior_recursive_model_umsy.pdf")

#Dr<-list(
#  DIR=tex_dir,
#  param_names=c("b","$S_{max}$","$\\rho$",paste("a",SR$BroodYear)),
#  MLE=c(repkf1$beta,repkf1$Smax,repkf1$rho,repkf1$alpha),
#  MCMC=cbind(beta_rb1,Smax_rb1,rho_rb1),
#  caption = "Parameter estimates for recursive Bayes Ricker model.",
#  digits=matrix(c(2,-2,2,2),ncol=6,nrow=length(SR$BroodYear)+2),
#  other=rbind(posterior_recursive1$fit_summary$summary[5:34,4],posterior_recursive1$fit_summary$summary[5:34,6],posterior_recursive1$fit_summary$summary[5:34,8]),
#  filename="recursive_tab_pr1.tex")
#results_table(Dr) 

#============================================================================================
#============================================================================================
#base case
mydata<-list(obs_logR=log(SR$R),obs_S=SR$S_adj,prbeta1=4.0,prbeta2=4.0)


recursive<-list(
  dat=mydata,
  params=parameters_recursive,
  rndm="alpha",
  dll="Rickerkf_ratiovar",
  DIR="."
  )

recursivebase <- runTMB(recursive,comps=TRUE)
recursivebase$opt

TMBAIC(recursivebase$opt) #80.54305
2*4-2*-36.27152


recursiveobj <- recursivebase$obj
repkf<-recursiveobj$report()

repkf<-recursiveobj$report()

predR2<-matrix(NA,nrow=length(SR$S_adj),ncol=length(repkf$alpha))

s_pred<-seq(0,max(SR$S_adj)*1.05,length=length(SR$S_adj))

for(i in 1:length(repkf$alpha)){
  #predR2[,i]<- SR$S_adj*exp(repkf$alpha[i]-repkf$beta*SR$S_adj)
  predR2[,i]<- s_pred*exp(repkf$alpha[i]-repkf$beta*s_pred)
}


df<-data.frame(S=rep(SR$S_adj,length(repkf$alpha)),
  predS=rep(s_pred,length(repkf$alpha)),
    predR=c(predR2),
    R=rep(SR$R,length(repkf$alpha)),
    a=rep(repkf$alpha,each=length(repkf$alpha)),
    umsy=rep(repkf$umsy,each=length(repkf$umsy)),
    ayr=as.factor(rep(SR$BroodYear,each=length(repkf$alpha))),
    model="Kalman filter",
    BroodYear=rep(SR$BroodYear,length(repkf$alpha)))


df<-df[sort(order(df$S)),]


p <- ggplot(df)
#p <- p + geom_point(aes(x=S_adj,y=R))
p <- p + geom_line(aes(x=predS/1000,y=predR/1000, color=ayr), size=2, alpha=0.6)
p <- p + geom_text(aes(x=S/1000,y=R/1000,label=BroodYear ),hjust=0, vjust=0)
p <- p + theme_bw(16) + scale_color_viridis_d(end = 0.9, option="D")
p <- p + coord_cartesian(xlim=c(0,max(df$S)/1000*1.05))
p <- p + labs(title = "Recursive Bayes Ricker model", x = "Spawners (1,000s)", y = "Recruits (1,000s)", color = "Year\n") 
p
ggsave("../figs/recursive_pred.pdf", plot=p, width=10,height=7)

recursiveB<-list(
  obj=recursiveobj,
  nchain=3,
  iter=iteracs,
  lowbd=c(0.1,-13.5,0.0,-3.0),
  hibd=c(4.0,-9.,1.0,5.0)
)

posterior_recursive<-posteriorsdf(recursiveB)
recrsdf<-posterior_recursive$posteriors

a_rb<-(recrsdf$value[recrsdf$parameters=="alphao"])
beta_rb<-exp(recrsdf$value[recrsdf$parameters=="logbeta"])
Smax_rb<-1/exp(recrsdf$value[recrsdf$parameters=="logbeta"])
rho_rb<-(recrsdf$value[recrsdf$parameters=="rho"])
umsy_rb<-.5*a_rb-0.07*a_rb^2


rhodf0<-recrsdf[recrsdf$parameters=="rho",]
rhodf0t<-rhodf0
rhodf0t$value<-rbeta(nrow(rhodf0),3,3)
rhodf0p<-rbind(rhodf0,rhodf0t)
rhodf0p$distribution<-rep(c("posterior","prior"),each=nrow(rhodf0))
rhodf0p$scn<-"base 3, 3"

#rh0<-ggplot(rhodf0,aes(value))
#rh0<-rh0+geom_density(size=1.2)
#rh0<-rh0+geom_vline(aes(xintercept=quantile(rho_rb,probs=c(.5))),color="red",size=1.2)
#rh0<-rh0+theme_bw(16)
#rh0

unique(recrsdf$parameters)
sob <- recrsdf[grep("logbeta",recrsdf$parameters),]
sob$value <- exp(sob$value)

sobvals <- rep(sob$value, )


soa <- recrsdf[grep("alpha",recrsdf$parameters),]
soa$umsy=.5*soa$value-0.07*soa$value^2
umsyposteriorsummary<-aggregate(soa$umsy,list(soa$parameters),function(x){quantile(x,probs=c(0.025,.5,.975))})
umsyposteriorsummary<-umsyposteriorsummary[c(1,12,23,25:30,2:11,13:22,24),]


sobvals <- rep(sob$value,length(unique(soa$parameters )))
soa$Smsy<- soa$value/sobvals * (0.5 - 0.07 * soa$value)
Smsyposteriorsummary<-aggregate(soa$Smsy,list(soa$parameters),function(x){quantile(x,probs=c(0.025,.5,.975))})
Smsyposteriorsummary<-Smsyposteriorsummary[c(1,12,23,25:30,2:11,13:22,24),]
 


dfa<-data.frame(broodyear=SR$BroodYear,a=c(repkf$alpha,posterior_recursive$fit_summary$summary[5:34,6]), 
  type=rep(c("MLE","Bayes"),each=length(SR$BroodYear)),lower=c(rep(NA,length(SR$BroodYear)),posterior_recursive$fit_summary$summary[5:34,4]),
  upper=c(rep(NA,length(SR$BroodYear)),posterior_recursive$fit_summary$summary[5:34,8]))


pa<-ggplot(dfa)
pa<-pa+geom_line(aes(x=broodyear,y=a,col=type), size=2)
pa<-pa+geom_ribbon(aes(x=broodyear,ymin=lower,ymax=upper, fill=type),alpha=.4)
pa<-pa+theme_bw(16) +scale_fill_viridis_d(end = 0.8, option="B")
pa<-pa+scale_color_viridis_d(end = 0.8, option="B")
pa<-pa+labs(title = "Recursive Bayes model - time series", y = expression(a), x = "Brood year",
 fill="Type", color="Type") 
pa
ggsave("../figs/recursive_a.pdf", plot=pa, width=10,height=7)


dfu<-data.frame(broodyear=rep(SR$BroodYear,2),umsy=c(repkf$umsy,umsyposteriorsummary$x[,2]), 
  type=rep(c("MLE","Bayes"),each=length(SR$BroodYear)),lower=c(rep(NA,length(SR$BroodYear)),umsyposteriorsummary$x[,1]),
  upper=c(rep(NA,length(SR$BroodYear)),umsyposteriorsummary$x[,3]))


pu<-ggplot(dfu)
pu<-pu+geom_line(aes(x=broodyear,y=umsy,col=type), size=2)
pu<-pu+geom_ribbon(aes(x=broodyear,ymin=lower,ymax=upper, fill=type),alpha=.4)
pu<-pu+theme_bw(16) + scale_fill_viridis_d(end = 0.8, option="B")
pu<-pu+scale_color_viridis_d(end = 0.8, option="B")
pu<-pu+labs(title = "Recursive Bayes model -  Umsy time series", y = expression(u[MSY]), x = "Brood year") 
pu
ggsave("../figs/recursive_umsy.pdf", plot=pu, width=10,height=7)


dfs<-data.frame(broodyear=rep(SR$BroodYear,2),Smsy=c(repkf$Smsy,Smsyposteriorsummary$x[,2]), 
  type=rep(c("MLE","Bayes"),each=length(SR$BroodYear)),lower=c(rep(NA,length(SR$BroodYear)),Smsyposteriorsummary$x[,1]),
  upper=c(rep(NA,length(SR$BroodYear)),Smsyposteriorsummary$x[,3]))


ps <- ggplot(dfs)
ps <- ps + geom_line(aes(x=broodyear,y=Smsy,col=type), size=2)
ps <- ps + geom_ribbon(aes(x=broodyear,ymin=lower,ymax=upper, fill=type),alpha=.4)
ps <- ps + theme_bw(16) + scale_fill_viridis_d(end = 0.8, option="B")
ps <- ps + scale_color_viridis_d(end = 0.8, option="B")
ps <- ps + labs(title = "Recursive Bayes model -  Smsy time series", y = expression(S[MSY]), x = "Brood year") 
ps <- ps + scale_y_continuous(labels = scales::comma) + coord_cartesian(ylim = c(0, 430000)) 
ps
ggsave("../figs/recursive_Smsy.pdf", plot=ps, width=10,height=7)

Dr<-list(
  DIR="../tex",
  param_names=c("$b$","$S_{max}$","$\\rho$",paste("$a$",SR$BroodYear)),
  MLE=c(repkf$beta,repkf$Smax,repkf$rho,repkf$alpha),
  MCMC=cbind(beta_rb,Smax_rb,rho_rb),
  caption = "Parameter estimates for recursive Bayes Ricker model.",
  digits=matrix(c(-2,rep(2,32)),ncol=6,nrow=length(SR$BroodYear)+3),
  other=rbind(posterior_recursive$fit_summary$summary[5:34,4],posterior_recursive$fit_summary$summary[5:34,6],posterior_recursive$fit_summary$summary[5:34,8]),
  filename="recursive_tab.tex",
  labs="estparrec")

results_table(Dr) 




#Drumsy<-list(
#  DIR=tex_dir,
#  param_names=c(paste("$U_{MSY}$",SR$BroodYear)),
#  MLE=c(repkf$umsy),
#  MCMC=NA,
#caption = "$U_{MSY}$ estimates for recursive Bayes Ricker model.",
#  digits=matrix(c(2),ncol=6,nrow=length(SR$BroodYear)),
#  other=rbind(umsyposteriorsummary$x[,1],umsyposteriorsummary$x[,2],umsyposteriorsummary$x[,3]),
#  filename="recursive_tab_umsy.tex",
#  labs="estumsy")

#results_table(Drumsy) 


#============================================================================================
#============================================================================================
# high observation error
mydata2<-list(obs_logR=log(SR$R),obs_S=SR$S_adj,prbeta1=3.0,prbeta2=2)
mydata2<-list(obs_logR=log(SR$R),obs_S=SR$S_adj,prbeta1=4.0,prbeta2=1.5)
recursive2<-list(
  dat=mydata2,
  params=parameters_recursive,
  rndm="alpha",
  dll="Rickerkf_ratiovar",
  DIR="."
  )

recursivep2<-runTMB(recursive2,comps=FALSE)
recursivep2$opt
TMBAIC(recursivep2$opt)
TMBAIC(simple$opt)
recursiveobj2<-recursivep2$obj
repkf2<-recursiveobj2$report()

recursiveB2<-list(
  obj=recursiveobj2,
  nchain=3,
  iter=iteracs,
  lowbd=c(0.1,-13.5,0.0,-3.0),
  hibd=c(4.0,-9.,1.0,5.0)
)

posterior_recursive2<-posteriorsdf(recursiveB2)
recrsdf2<-posterior_recursive2$posteriors

a_rb2<-(recrsdf2$value[recrsdf2$parameters=="alphao"])
beta_rb2<-exp(recrsdf2$value[recrsdf2$parameters=="logbeta"])
Smax_rb2<-1/exp(recrsdf2$value[recrsdf2$parameters=="logbeta"])
rho_rb2<-(recrsdf2$value[recrsdf2$parameters=="rho"])
umsy_rb2<-.5*a_rb2-0.07*a_rb2^2


rhodf2<-recrsdf2[recrsdf2$parameters=="rho",]
rhodf2t<-rhodf2
rhodf2t$value<-rbeta(nrow(rhodf2),3,2)
rhodf2p<-rbind(rhodf2,rhodf2t)
rhodf2p$distribution<-rep(c("posterior","prior"),each=nrow(rhodf2))
rhodf2p$scn<-"high obs 3, 2"

#rh2<-ggplot(rhodf2p,aes(value))
#rh2<-rh2+geom_density(size=1.2,aes(color=distribution))
##rh2<-rh2+geom_density(aes(rbeta(1500000,3,2)),color="blue",size=1.2)
#rh2<-rh2+geom_vline(aes(xintercept=quantile(rho_rb2,probs=c(.5))),color="red",size=1.2)
#rh2<-rh2+theme_bw(16)
#rh2


soa2<-recrsdf2[grep("alpha",recrsdf2$parameters),]
summary(soa2)
soa2$umsy=.5*soa2$value-0.07*soa2$value^2
umsyposteriorsummary2<-aggregate(soa2$umsy,list(soa2$parameters),function(x){quantile(x,probs=c(0.025,.5,.975))})
umsyposteriorsummary2<-umsyposteriorsummary2[c(1,12,23,25:30,2:11,13:22,24),]




#============================================================================================
#============================================================================================
#low observation error


mydata3<-list(obs_logR=log(SR$R),obs_S=SR$S_adj,prbeta1=2.0,prbeta2=3.0)


recursive3<-list(
  dat=mydata3,
  params=parameters_recursive,
  rndm="alpha",
  dll="Rickerkf_ratiovar",
  DIR="."
  )

recursivep3<-runTMB(recursive3,comps=FALSE)
TMBAIC(recursivep3$opt)
recursivep3$opt
recursiveobj3<-recursivep3$obj

repkf3<-recursiveobj3$report()



recursiveB3<-list(
  obj=recursiveobj3,
  nchain=3,
  iter=iteracs,
  lowbd=c(0.1,-13.5,0.0,-3.0),
  hibd=c(4.0,-9.,1.0,5.0)
)

posterior_recursive3<-posteriorsdf(recursiveB3)
recrsdf3<-posterior_recursive3$posteriors

a_rb3<-(recrsdf3$value[recrsdf3$parameters=="alphao"])
beta_rb3<-exp(recrsdf3$value[recrsdf3$parameters=="logbeta"])
Smax_rb3<-1/exp(recrsdf3$value[recrsdf3$parameters=="logbeta"])
rho_rb3<-(recrsdf3$value[recrsdf3$parameters=="rho"])
umsy_rb3<-.5*a_rb3-0.07*a_rb3^2




rhodf3<-recrsdf3[recrsdf3$parameters=="rho",]
rhodf3t<-rhodf3
rhodf3t$value<-rbeta(nrow(rhodf3),2,3)
rhodf3p<-rbind(rhodf3,rhodf3t)
rhodf3p$distribution<-rep(c("posterior","prior"),each=nrow(rhodf3))
rhodf3p$scn<-"low obs 2, 3"

soa3<-recrsdf3[grep("alpha",recrsdf3$parameters),]
soa3$umsy<-.5*soa3$value-0.07*soa3$value^2
umsyposteriorsummary3<-aggregate(soa3$umsy,list(soa3$parameters),function(x){quantile(x,probs=c(0.025,.5,.975))})
umsyposteriorsummary3<-umsyposteriorsummary3[c(1,12,23,25:30,2:11,13:22,24),]

names(soa3)
dim(soa3)
summary(soa3)
unique(soa3$parameters)
#predicted recruitment
ls()

moltentmp<-melt(soa[,-c(1,2)])
moltentmp$iterations<-paste(soa$iterations,soa$chains,sep=".")
tmp<-cast(moltentmp[moltentmp$variable=="value",],formula =  iterations~ parameters , mean, value = 'value')
tmpu<-cast(moltentmp[moltentmp$variable=="umsy",],formula =  iterations~ parameters , mean, value = 'value')

moltentmp1<-melt(soa1[,-c(1,2)])
moltentmp1$iterations<-paste(soa1$iterations,soa1$chains,sep=".")
tmp1<-cast(moltentmp1[moltentmp1$variable=="value",],formula =  iterations~ parameters , mean, value = 'value')
tmpu1<-cast(moltentmp1[moltentmp1$variable=="umsy",],formula =  iterations~ parameters , mean, value = 'value')

moltentmp2<-melt(soa2[,-c(1,2)])
moltentmp2$iterations<-paste(soa2$iterations,soa2$chains,sep=".")
tmp2<-cast(moltentmp2[moltentmp2$variable=="value",],formula =  iterations~ parameters , mean, value = 'value')
tmpu2<-cast(moltentmp2[moltentmp2$variable=="umsy",],formula =  iterations~ parameters , mean, value = 'value')

moltentmp3<-melt(soa3[,-c(1,2)])
moltentmp3$iterations<-paste(soa3$iterations,soa3$chains,sep=".")
tmp3<-cast(moltentmp3[moltentmp3$variable=="value",],formula =  iterations~ parameters , mean, value = 'value')
tmpu3<-cast(moltentmp3[moltentmp3$variable=="umsy",],formula =  iterations~ parameters , mean, value = 'value')
sum(moltentmp$value[moltentmp$variable=="umsy"]>0)
summary(moltentmp)
dim(moltentmp[moltentmp$variable=="umsy",])

dim(tmpu)
head(tmp[,c(2,13,24,26:31,3:12,14:23,25)])
head(tmpu[,c(2,13,24,26:31,3:12,14:23,25)])

#this will take time. Option to read in "../data/vrap_RB_results.rds"
source("VRAPavgvar_calc.R")

meanu<-c(quantile(umsy_simple,.5),quantile(avgu0,.5),quantile(avgu2,.5),quantile(avgu3,.5)) #
meana<-c(quantile(alpha,.5),quantile(avga0,.5),quantile(avga2,.5),quantile(avga3,.5)) #
meanR<-c(quantile(meanRsimple,.5),quantile(meanR0,.5),quantile(meanR2,.5),quantile(meanR3,.5))#quantile(meanR1,.5),
varR<-c(quantile(varRsimple,.5),quantile(varR0,.5),quantile(varR2,.5),quantile(varR3,.5)) #,quantile(varR1,.5)
bs<-c(quantile(Smax,.5),quantile(Smax_rb,.5),quantile(Smax_rb2,.5),quantile(Smax_rb3,.5))



vraptab<- data.frame(scenario=rep(c("simple Ricker", "RB base 3, 3","RB high obs 3, 2","RB low obs 2, 3"),1),aavg4=meana,
  b=bs,meanR=meanR,varR=varR,uavg4=meanu)

colnames(vraptab)<-c("scenario","$\\widetilde{a_{avg4}}$","$\\widetilde{b}$","meanR","varR","$U_{MSY avg}$")
 vraptabtmp<-xtable(vraptab, digits=matrix(c(2,rep(2,nrow(vraptab)-1)),ncol=ncol(vraptab)+1,nrow=nrow(vraptab),byrow=F),sanitize.text.function=function(x){x},
,caption = "Median parameter estimates across simple Ricker recruitment model and 
 three time-varying productivity scenarios (RB) with different $\\rho$ priors. Parameters were transformed to meet VRAP requirements.",
 label="vraptab" )


print(vraptabtmp,sanitize.text.function = function(x) {x},
      include.rownames = FALSE, 
file="../tex/vrap_params2.tex",caption.placement = "top", label="vraptab")



#========================================================================
#Comparison tables
#parameter estimates

tab<-data.frame(Parameter=c("b","$S_{max}$","$\\rho$",paste("$\\alpha$",SR$BroodYear)),
                      "base" =c(apply(cbind(beta_rb,Smax_rb,rho_rb),2,function(x) quantile(x, .5)),exp(posterior_recursive$fit_summary$summary[5:34,6])),
                      "uninformative"=c(apply(cbind(beta_rb1,Smax_rb1,rho_rb1),2,function(x) quantile(x, .5)),exp(posterior_recursive1$fit_summary$summary[5:34,6])),
                      "high"=c(apply(cbind(beta_rb2,Smax_rb2,rho_rb2),2,function(x) quantile(x, .5)),exp(posterior_recursive2$fit_summary$summary[5:34,6])),
                      "low"=c(apply(cbind(beta_rb3,Smax_rb3,rho_rb3),2,function(x) quantile(x, .5)),exp(posterior_recursive3$fit_summary$summary[5:34,6])))


 tabtmp<-xtable(tab, digits=matrix(c(-2,rep(2,nrow(tab)-1)),ncol=ncol(tab)+1,nrow=nrow(tab),byrow=F)
,caption = "Median parameter estimates for the recursive Bayes model across four $\\rho$ prior scenarios. " )

  print(tabtmp,sanitize.text.function = function(x) {x},
      include.rownames = FALSE, 
  file="../tex/recursive_tab_params_comparison.tex",caption.placement = "top",
  label="parreccomp")


#rho estimates, priors, posteriors
#table for vrap





#========================================================================
#Comparison figures
#MLE versus posteriors


rhodfp<-rbind(rhodf0p,rhodf1p,rhodf2p,rhodf3p)
names(rhodfp)

linerhodf<-data.frame(scn=rep(c("uninformative 1, 1","base 3, 3","low obs 2, 3","high obs 3, 2"),each=2),
  vals=c(quantile(rho_rb1,probs=c(.5)),repkf1$rho,
    quantile(rho_rb,probs=c(.5)),repkf$rho,
    quantile(rho_rb3,probs=c(.5)),repkf3$rho, 
    quantile(rho_rb2,probs=c(.5)),repkf2$rho),
  type=as.factor(rep(c("Median posterior","MLE"),4)))

rhodf3p$median<-quantile(rho_rb3,probs=c(.5))
rhodf3p$mle<-repkf3$rho


pr<-ggplot(rhodfp,aes(value))
pr<-pr+geom_density(size=1.2,aes(color=distribution),alpha=.6)
pr<-pr+facet_wrap(~ scn)
pr<-pr+geom_vline(data=linerhodf,aes(xintercept=vals,color=type),size=1.3)
pr<-pr+ scale_color_viridis_d(end = 0.9, option="B")
#scale_color_manual(values=c("red","black"))
#scale_color_manual(values=c("red","black","#E69F00", "#56B4E9"))
pr<-pr+theme_bw(16) 
pr<-pr+labs(x = expression(paste(rho,"values")), y="Density", color='Distribution') 
pr
ggsave("../figs/priors_posteriors_rho.pdf", plot=pr, width=10,height=8)



dfu<-data.frame(broodyear=rep(SR$BroodYear,8),
  umsy=c(umsyposteriorsummary$x[,2],umsyposteriorsummary1$x[,2],
    umsyposteriorsummary2$x[,2],umsyposteriorsummary3$x[,2],
    repkf$umsy,repkf1$umsy,repkf2$umsy,repkf3$umsy
    ), #,umsyposteriorsummary3$x[,2]
  scn=rep(rep(c("base 3, 3","uninformative 1, 1","low obs 3, 2","high obs 2, 3"),each=length(SR$BroodYear)),2),#,"2,3"
  lower=c(umsyposteriorsummary$x[,1],umsyposteriorsummary1$x[,1],
    umsyposteriorsummary2$x[,1],umsyposteriorsummary3$x[,1],
    rep(NA,each=length(SR$BroodYear)*4)),
  upper=c(umsyposteriorsummary$x[,3],umsyposteriorsummary1$x[,3],
    umsyposteriorsummary2$x[,3],umsyposteriorsummary3$x[,3],
    rep(NA,each=length(SR$BroodYear)*4)),
  type=rep(c("Posterior", "MLE"),each=length(SR$BroodYear)*4)
  )




pu<-ggplot(dfu)
pu<-pu+geom_ribbon(aes(x=broodyear,ymin=lower,ymax=upper, fill=scn),alpha=.4)
pu<-pu+geom_line(aes(x=broodyear,y=umsy,col=scn), size=1.2)
pu<-pu+ facet_wrap(~type) +scale_fill_viridis_d(end = 0.9, option="D")
pu<-pu+theme_bw(16) + scale_color_viridis_d(end = 0.9, option="D")
pu<-pu+labs(title = "Recursive Bayes model -  Umsy time series", y = expression(u[MSY]), x = "Brood year") 
pu





dfa<-data.frame(broodyear=rep(SR$BroodYear,8),
  a=c(posterior_recursive$fit_summary$summary[5:34,6],
    posterior_recursive1$fit_summary$summary[5:34,6],
    posterior_recursive2$fit_summary$summary[5:34,6],
    posterior_recursive3$fit_summary$summary[5:34,6],
    repkf$alpha,repkf1$alpha,repkf2$alpha,repkf3$alpha
    ), #,umsyposteriorsummary3$x[,2]
  scn=rep(rep(c("base 3, 3","uninformative 1, 1","low obs 3, 2","high obs 2, 3"),each=length(SR$BroodYear)),2),#,"2,3"
  lower=c(posterior_recursive$fit_summary$summary[5:34,4],
    posterior_recursive1$fit_summary$summary[5:34,4],
    posterior_recursive2$fit_summary$summary[5:34,4],
    posterior_recursive3$fit_summary$summary[5:34,4],
    rep(NA,each=length(SR$BroodYear)*4)),
  upper=c(posterior_recursive$fit_summary$summary[5:34,8],
    posterior_recursive1$fit_summary$summary[5:34,8],
    posterior_recursive2$fit_summary$summary[5:34,8],
    posterior_recursive3$fit_summary$summary[5:34,8],
    rep(NA,each=length(SR$BroodYear)*4)),
  type=rep(c("Posterior", "MLE"),each=length(SR$BroodYear)*4)
  )


pa<-ggplot(dfu)
pa<-pa+geom_ribbon(aes(x=broodyear,ymin=lower,ymax=upper, fill=scn),alpha=.4)
pa<-pa+geom_line(aes(x=broodyear,y=umsy,col=scn), size=1.2)
pa<-pa+ facet_wrap(~type) + scale_fill_viridis_d(end = 0.9, option="D")
pa<-pa+theme_bw(16)+scale_color_viridis_d(end = 0.9, option="D")
pa<-pa+labs(title = expression(paste("Recursive Bayes model - ",a[t] ," time series")), y = expression(a[t]), x = "Brood year") 
pa
ggsave("../recursive_a_priors.pdf", plot=pa, width=10,height=7)








