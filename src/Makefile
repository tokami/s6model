all: calcFmsy.so s6model.so s6modeltest.so

calcFmsy.so:
	Rscript --vanilla -e 'TMB::compile("calcFmsy.cpp")'

s6model.so:
	Rscript --vanilla -e 'TMB::compile("s6model.cpp")'

s6modeltest.so: s6modeltest.cpp
	Rscript --vanilla -e 'TMB::compile("s6modeltest.cpp")'

clean:
	rm -rf *o
