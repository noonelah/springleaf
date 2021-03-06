######################################################
# Function to get the Wj's
XI.gen = function(k){
  XI = matrix(0,k-1,k)
  
  XI[,1]=rep((k-1)^(-1/2),k-1)
  for (ii in 2:k)
  {
    XI[,ii]=rep( -(1+sqrt(k))/((k-1)^(1.5)), k-1)
    XI[ii-1,ii]=XI[ii-1,ii]+sqrt(k/(k-1))
  }
  
  return(XI)
}
##############################################################
# Y.matrix.gen is the matrix contianing the the simplex Wj's
# k is number of classes/labels
Y.matrix.gen=function(k,n,y ){
  Y.matrix = matrix(0,n,k-1)
  
  XI=XI.gen(k)
  
  for (ii in 1:n)
  {
    Y.matrix[ii,] = XI[,y[ii]]
  }
  return(Y.matrix)
  
}

###########################################################
pred=function(f){
  y=min(which(f==max(f)))
  return(y)
}

###########################################################
# Predict the vertex into different classes
pred.vertex = function (x, t, k){
  
  XI=XI.gen(k)
  
  p=ncol(x);
  
  betas <- matrix(data = t, nrow = p+1, ncol = k-1)
  beta <- betas[1:p,]
  beta0 <- betas[p+1,]
  
  f.matrix = t(t(x%*% beta)+beta0)
  
  inner.matrix = f.matrix %*% XI
  
  z=apply(inner.matrix,1,pred)
  
  return(z)
  
}

##############################################################
# Probability of f being classified into class i
# x is covariates of the observed labels
# k is number of class/labels
# t is the vector obtained from optim() function

prob.vertex = function (x, t, k){  
  XI=XI.gen(k)
  
  n = nrow(x); p=ncol(x);
  
  betas <- matrix(data = t, nrow = p+1, ncol = k-1)
  beta <- betas[1:p,]
  beta0 <- betas[p+1,]
  
  f.matrix = t(t(x%*% beta)+beta0)
  
  inner.matrix = f.matrix %*% XI

  fir.der.matrix = matrix(as.numeric(1/fir.der(inner.matrix)), nrow = n, ncol = k) 
 
  temp = apply(fir.der.matrix,1,sum)

  z = fir.der.matrix/temp

  return(z)
  
}

##############################################################
# Loss function and its first derivative
##############################################################
fir.der <-function(u){
  a = 1; c= 0;
  z=rep(-1,length(u))
  index<-which(u>=(c/(1+c)))

  if (a > 100)
  {
    z[index]<- -exp( -((1+c)*u[index]-c) )
  }
  if (a <= 100)
  {
    z[index]<- -((a/( (1+c)*u[index]-c+a ))^(a+1))
  }

  z <- mpfr(z,256)

  return(z)
}

orig <-function(u){
  a = 1; c= 0;
  z=1-u
  index<-which(u>=(c/(1+c)))
  if (a > 100)
  {
    z[index]= 1/(1+c) * exp( -((1+c)*u[index]-c) )
  }
  if (a <= 100)
  {
    z[index]= 1/(1+c) * (a/( (1+c)*u[index]-c+a ))^a
  }
  return(z)
}

#############################################################
# fr & grr
fr=function(x,y,t,k,p,n,lambda){
  Y.matrix = Y.matrix.gen(k,n,y)
  
  betas <- matrix(data = t,nrow = p+1,ncol = k-1)
  beta <- betas[1:p,]
  beta0 <- betas[p+1,]
  
  f.matrix = t(t(x %*% beta)+beta0)
  
  z=sum( orig( apply(Y.matrix * f.matrix,1,sum) ) ) / n
  
  z = z+ lambda*sum(beta^2)
  
  return(z)
}

grr=function(x,y,t,k,p,n,lambda){
  
  Y.matrix = Y.matrix.gen(k,n,y)
  
  #######
  z=numeric(length(t))
  
  betas <- matrix(t,nrow = p+1,ncol = k-1)
  beta <- betas[1:p,]
  beta0 <- betas[p+1,]
  
  f.matrix = t(t(x %*% beta)+beta0)
  
  temp = as.numeric(fir.der(apply(Y.matrix * f.matrix,1,sum)))
  
  for (j in 1:(k-1)) ## j= 1 to k-1 for different parts of derivatives
  {
    
    z[((p+1)*j-p):((p+1)*j-1)] = apply(Y.matrix[,j]*temp*x,2,mean)
    
    z[((p+1)*j-p):((p+1)*j-1)] = z[((p+1)*j-p):((p+1)*j-1)] + 2*lambda*beta[,j]
    
    z[(p+1)*j] = sum( Y.matrix[,j]*temp )/n
    
  } # for (j in 1:(k-1)) ## j= 1 to k-1 for different parts of derivatives
  
  
  
  return(z)
}

###############################################################
# Tuning
angle.tune = function(x.train, y.train, x.tune, y.tune, k){
  
  tune.error = Inf
  t.trace = 0
  lambda.temp = 0

  p = ncol(x.train)
  n = nrow(x.train)
  
  for (iii in 1:21)
  {
    lambda = 2^(iii-11)
    t = optim(par = rep(0,((k-1)*(p+1))),fn = fr,gr = grr,x = x.train, y = y.train, p=p, n=n, k = k, lambda=lambda, method="BFGS") $par
    temp = length(which(pred.vertex(x.tune, t=t, k=k) != y.tune))
    if (temp < tune.error)
    {
      tune.error = temp
      t.trace = t
      lambda.temp = lambda		
    }
  }
  
  t=t.trace
  lambda = lambda.temp
  out <- list(t,lambda)
  names(out) <- c('betas','lambda')
  
  return(out)
  
}

##############################################################
# Refitting
refit <- function(x.train,y.train,x.test,y.test,k,betas){
  n <- nrow(x.train); p <- ncol(x.train);
  
  # Extracting the beta's
  b.mat <- matrix(betas,nrow = p+1, ncol = k-1)
  beta <- b.mat[1:p,]
  beta0 <- b.mat[p+1,]
  
  # New matrix to work with
  x.new <- t(t(x.train %*% beta)+beta0)
  
  # Getting etas from optim
  t <- optim(par = rep(0,((k-1)*(k))),fn = fr, gr = grr,x = x.new, y = y.train, k = k, p = k-1, n = n, lambda = 0, method = "BFGS")$par
  
  # Extracting Eta's
  e.mat <- matrix(t, nrow = k, ncol = k-1); 
  eta <- e.mat[1:k-1,]; eta0 <- e.mat[k,];
  
  # Inner Products
  Wj <- XI.gen(k);
  f.matrix <- t(t(t(t(x.test %*% beta)+beta0) %*% eta) + eta0);
  inner.mat <- f.matrix %*% Wj;
  class.pred <- apply(inner.mat,1,pred)
  class.prob <- prob.vertex(x = t(t(x.test %*% beta)+beta0), t = t, k = k)
  
  err <- length(which(class.pred != y.test))/length(y.test);
  
  output <- list(t,err,class.pred, class.prob)
  names(output) <- c('etas','error','class.prediction','class.probability')
  
  return(output)
  
}

################################################################
# For cleaning data set
################################################################
# Function to change the levels of categories from characters
# into integers
factorise <- function(u){
    u <- as.character(u)
    class <- unique(u)
    len <- length(class)
    for(i in 1:len){
     u[which(u == class[i])] <- i
    }
    u <- as.factor(u)
    return(u)
}

# Function to replace NA values in integer columns
integerise <- function(u){
    v <- rep.int(x = 0, times = length(u))
    posn <- which(is.na(u))
    v[posn] <- 1
    u[which(is.na(u))] <- 0
    out <- list(u,v)
    names(out) <- c('updated','posn')
    return(out)
}

# Function that takes in a matrix and replace the NA values
clean <- function(x){
    nobs <- nrow(x); np <- ncol(x);
    x.new <- matrix(0,nrow = nobs,ncol = 0)
    x.extra <- matrix(0,nrow = nobs, ncol = 0)
   for(i in 1:np){
        col <- x[,i]
        if(is.factor(col)){
            temp <- factorise(col)
            x.new <- cbind(x.new,temp)
        } else if(is.integer(col)){
            temp <- integerise(col)
            x.new <- cbind(x.new,temp$updated)
            x.extra <- cbind(x.extra,temp$posn)
        }
    }
    out <- cbind(x.new,x.extra)
    return(out)
}
