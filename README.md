> this is a private app. this doc is written for me

# gui viewer

web based app to process data

## what this app does

1. load NGS_\*\*\* file to get info about run,sampleid,prepkit,,, etc
2. show list of samples by run on the web
3. you can launch task to process data of samples you selected

## how to use

1. place config.yml at app root.
2. place NGS_\*\*\*.csv file, makefile at the place config.yml specified.
3. bundle install
4. bundle exec ruby app/app.rb -o 0.0.0.0 # -o is a options to set ip address app(Rack) use

## app structure

+ simple Ruby app based on framework [][sinatra]  
+ use some perl, python code for process data

#### misc

- rbenv + rbenv-build is reccomended to controll ruby-version  
- ruby library is called _gem_
- use bundle to manage 
- bundle is a ruby library manager. bundle install --path ./bendor/bundle for local install

[sinatra]:www.github.com/sinatra/sinatra
