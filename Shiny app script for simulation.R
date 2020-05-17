#Shiny app script for simulation
#Anyue Yin, Madeleine H.T. Ettaieb, et al. Population PK and PG analysis of mitotane

#Preparation####
library(shiny)
library(RxODE)
library(ggplot2)
library(dplyr)

#Design ui####
ui<-shinyUI(fluidPage(  
  headerPanel("Mitotane", windowTitle="Mitotane"), 
  sidebarLayout(
    position = "left",
    sidebarPanel(
      h5("Characteristics of patients:"),
      selectInput("SNPResult", "Is genotyping results available?",choices=c("YES","NO"), selected = "NO"),
      conditionalPanel(
        condition = "input.SNPResult == 'YES'",
        selectInput("SNP1", "CYP2C19*2 (rs4244285)",choices=c("G/G","G/A","A/A"), selected = "G/G"),
        
        selectInput("SNP2", "SLCO1B3 669A>G (rs7311358)",choices=c("A/A","A/G","G/G"), selected = "A/A"),
        
        selectInput("SNP3", "SLCO1B1 571T>C (rs4149057)",choices=c("T/C","C/C","T/T"), selected = "T/C")
        
      ),
      numericInput("Weight", "Weight of patient (kg)", 85),
      numericInput("Height", "Height of patient (cm)", 180),
      radioButtons("Gender", "Gender of patient (F/M)",choices=c("F","M"), selected = "M"),
      actionButton("Run", "Plot",icon("refresh"))
    ),
    mainPanel(
      tabsetPanel(type = "tabs",
                  tabPanel("Concentration prediction", plotOutput("plot1"))
                  
                  
      )
    )
  )
)
)


#Model structure####
ode <-"
C2 = A2/V2;
C3 = A3/V3;
d/dt(A1) = -KA*A1;                       
d/dt(A2) = KA*A1-CL*C2-Q*C2+Q*C3;
d/dt(A3) = Q*C2-Q*C3;"

mod1 <- RxODE(model=ode)


#Design server####
server<-shinyServer(function(input, output) ({
  output$plot1 <- renderPlot({
    blank<-data.frame(time=c(0,seq(14,1500,by=21)),Conc50=seq(0,35,length.out=72))
    ggplot(data=blank, aes(x=time, y=Conc50))+
      geom_blank()+
      ylab("Prediction of mitotane Concentration (mg/L)")+
      xlab("Time after first dose (day)")+
      theme_bw(base_size=15)+
      ggtitle("Concentration prediction")+
      theme(plot.title = element_text(hjust = 0.5,size = 20))
  })
  observeEvent(input$Run, {
    output$plot1 <- renderPlot({
      isolate({
        SNP1=as.character(input$SNP1)
        SNP2=as.character(input$SNP2)
        SNP3=as.character(input$SNP3)
        WT=as.numeric(input$Weight)
        HT=as.numeric(input$Height)
        SEX=as.character(input$Gender)
        SNPResult=as.character(input$SNPResult)
        
        #simulation
        conc.limits <- c(0, 13.99,17.99, 19.99 ,100)  #decision rule limits
        time.cut <-c(0,199,399,599,799,999,1199,1399,1599) #time for occasion change
        dose.m1 <- c(500,0,-1000,-4000)   #dose change level1
        dose.m2 <- c(1500,0,-1000,-4000)  #dose change level2
        
        
        # Initialize other variables
        vars <- c("A1","A2","A3")
        result.C.all<-data.frame()
        
        #parameter values
        CLSNP1<-1
        CLSNP2<-1
        CLSNP3<-1
        
        if(SNP1=="G/A"|SNP1=="A/A"){
          CLSNP1=0.551
        }
        if(SNP2=="A/G"|SNP2=="G/G"){
          CLSNP2=0.601
        }
        if(SNP3=="C/C"){
          CLSNP3=0.753
        }
        if(SNP3=="T/T"){
          CLSNP3=2.49
        }
        
        
        if(SNPResult=="NO"){
          A=217
          B=8450
          C=609
          D=15500
          E=0
          G=1.12
          OMCL=0.663
          OMV2=0.635
          OMQ=1.005
          OMV3=0.804
          OMIOV=0.312
        } else {
          A=298
          B=6210
          C=883
          D=18100
          E=1.1
          G=1.22
          OMCL=0.430
          OMV2=0.472
          OMQ=0.973
          OMV3=0.888
          OMIOV=0.316
        }
        
        if(SEX=="F"){
          LBW<-round(0.252*WT+0.473*HT-48.3,1)
        }
        if(SEX=="M"){
          LBW<-round(0.407*WT+0.267*HT-19.2,1)
        }
        FAT<-WT-LBW
        CL<-A*CLSNP1*CLSNP2*CLSNP3*(LBW/56.6)^E
        VC<-B*(FAT/23.6)^G
        Q<-C
        VP<-D
        KA<-15
        
        #Determine the individual starting dose  
        inits <- c(0,0,0) 
        ev <- eventTable()
        ev$add.dosing(dose = 6000, dosing.interval = 1, nbr.doses = 21)
        ev$add.sampling(0:21)	
        params <- c(KA = KA, CL = CL, V2 = VC, 
                    Q = Q, V3 = VP)   
        x <- mod1$run(params, ev, inits)
        x3<-x[dim(x)[1], vars]
        x3[1]<-0
        for(i in c(1:4)){
          inits <- x3 
          ev <- eventTable()
          ev$add.dosing(dose = 6000+dose.m1[1]*i, dosing.interval = 1, nbr.doses = 21)
          ev$add.sampling(0:21)	
          params <- c(KA = KA, CL = CL, V2 = VC, 
                      Q = Q, V3 = VP)   
          x <- mod1$run(params, ev, inits)
          x3<-x[dim(x)[1], vars]
          x3[1]<-0
        }
        conc1<-x[dim(x)[1]-7, "C2"] #the concentration on day 98 when dosing by starting with 6g per day and then increasing by 0.5g per 21 days
        
        if(round(6/conc1*14,1)<trunc(6/conc1*14)+0.4){
          unit.dose<-as.numeric(round(6/conc1*14,0)*1000)
        }else if(round(6/conc1*14,1)>=trunc(6/conc1*14)+0.4 & round(6/conc1*14,1)<=trunc(6/conc1*14)+0.6){
          unit.dose<-as.numeric((trunc(6/conc1*14)+0.5)*1000)
        }else{
          unit.dose<-as.numeric(round(6/conc1*14,0)*1000)
        }
        
        #Simulation, 100 times
        set.seed(10) 
        ETA1.all<- rnorm(100, mean = 0, sd = OMCL)
        set.seed(10)
        ETA2.all<- rnorm(100, mean = 0, sd = OMV2)
        set.seed(10)
        ETA3.all<- rnorm(100, mean = 0, sd = OMV3)
        set.seed(10)
        ETA4.all<- rnorm(100, mean = 0, sd = OMQ)
        
        for(z in c(1:100)){
          result.C <- data.frame()
          x1<- data.frame()
          time.total<- data.frame()
          time.target<-data.frame(A=NA)
          
          
          ETA1<- ETA1.all[z]
          ETA2<- ETA2.all[z]
          ETA3<- ETA3.all[z]
          ETA4<- ETA4.all[z]
          
          s2.before<-1
          IOV<- rnorm(1, mean = 0, sd = OMIOV)
          n<-0
          for (i in c(1:70)) {
            if (i==1) {  		            #treatment start 
              inits <- c(0,0,0)
              last.dose<-unit.dose
              this.m<-0
            } else if (i %in% c(2:6)){	#if the target was reached, dose change level2 will be used 
              x2<-x[dim(x)[1], vars]
              x2[1]<-0
              inits <- x2
              conc <- x[dim(x)[1]-7, "C2"]
              s1 <- cut(conc, conc.limits, labels=F)
              if(s1==2){
                n<-n+1
                time.target[n,1]<-x[dim(x)[1]-7, "time"]+(i-2)*(21)
              }
              time1<-x[dim(x)[1]-7, "time"]+(i-2)*(21)
              if(time1<=time.target[1,1]|is.na(time.target[1,1])){
                this.m <- dose.m1[s1]	 
              } else {
                this.m <- dose.m2[s1]	
              }
            } else {		                #	after 126 days, use dose change level2 
              x2<-x[dim(x)[1], vars]
              inits <- x2
              x2[1]<-0
              conc <- x[dim(x)[1]-7, "C2"]
              s1 <- cut(conc, conc.limits, labels=F)
              this.m <- dose.m2[s1]
            }
            this.dose<-max(round(last.dose+this.m,0),0)
            last.dose<-this.dose
            
            #Dose and sampling 
            ev <- eventTable()
            ev$add.dosing(dose = this.dose, dosing.interval = 1, nbr.doses = 21)
            ev$add.sampling(0:21)		
            
            time<-1+(i-1)*21
            s2.now<-cut(time, time.cut, labels=F)
            if(s2.now!=s2.before){
              IOV<- rnorm(1, mean = 0, sd = 0.321)
            } 
            s2.before<-s2.now
            
            CL.j=CL*exp(ETA1+IOV)
            VC.j=VC*exp(ETA2)
            VP.j=VP*exp(ETA3)
            Q.j=Q*exp(ETA4)
            params <- c(KA = KA, CL = CL.j, V2 = VC.j, 
                        Q = Q.j, V3 = VP.j)   
            x <- mod1$run(params, ev, inits)				# Run simulation
            time.total<-x[,"time"]+(i-1)*(21)	      # Calculate time vector
            #result
            x1<-cbind(x,time.total,IOV,CL.j,VC.j,VP.j,Q.j,z,this.dose,unit.dose)
            x1<-as.data.frame(x1)
            result.C <- rbind(result.C,x1[-c(22),])
          }
          result.C.all<-rbind(result.C.all,result.C) #Combine all results together
        }
        
        
        #Prediction interval
        h1<-result.C.all %>%
          group_by(time.total) %>%
          mutate(time=time.total,ConCM=mean(C2),Conc95=quantile(C2, probs = c(0.95)),
                 Conc50=quantile(C2, probs = c(0.50)),Conc05=quantile(C2, probs = c(0.05)))%>%
          filter(z==1)
        h1<-data.frame(h1)
        
        #Target reach time
        h1$A<-0
        for (j in c(1:nrow(h1))){
          if(h1$Conc50[j]>=14){
            h1$A[j]<-1
            break
          }
        }
        
        h2<-h1[h1$A==1,]
        
        #Plot
        ggplot(data=h1[h1$time %in% c(0,seq(14,1500,by=21)),], aes(x=time, y=Conc50))+
          geom_ribbon(aes(ymin=Conc05,ymax=Conc95,fill="90% prediction interval"),alpha=0.3)+
          geom_line( aes(col="50th percentile"),size=1)+
          geom_point( aes(col="50th percentile"),size=1.5)+
          ylab("Prediction of mitotane Concentration (mg/L)")+
          xlab("Time after first dose (day)")+
          theme_bw(base_size=15)+
          geom_vline(data=h2,aes(xintercept = time),lty="dashed",col="red", size=1)+
          geom_hline(yintercept = 14,lty="dashed",col="black", size=1)+
          geom_hline(yintercept = 20,lty="dashed",col="black", size=1)+
          geom_text(data=h2,aes(x=time+10, y=35,label=time),size=5,col="blue",hjust = 0)+
          geom_text(aes(x=1000, y=35,label=paste("Starting dose: ", unit.dose/1000,"g")),size=5,col="black",hjust = 0)+
          ggtitle("Concentration prediction")+
          theme(plot.title = element_text(hjust = 0.5,size = 20))+
          scale_color_manual(name="", values = c("50th percentile"="black"),
                             guide = guide_legend(override.aes = list(linetype = c("solid"),
                                                                      shape = c(19))))+
          scale_fill_manual(name="", values = "black")
        
      })
    })
  })
  
}))

#Run Shiny app####
shinyApp(ui=ui,server=server)
                    
