#!/bin/env ruby
# encoding: utf-8

require 'colorize'
require 'json'
require 'nokogiri'
require 'open-uri'
require 'pry'
require 'scraperwiki'
require 'yaml'

def json_from(url)
  JSON.parse(open(url).read, symbolize_names: true)
end

def yaml_from(url)
  YAML.parse(open(url).read).to_ruby
end

def parl_group(id)
  (@pg ||= {})[id] ||= yaml_from('https://raw.githubusercontent.com/openpatata/openpatata-data/master/parliamentary_groups/%s.yaml' % id)
end

def scrape_members(term, url)
  json_from(url).each do |file|
    mp = yaml_from(file[:download_url])
    next if mp['tenures'].nil?

    data = {
      id: nil,
      name: mp['name']['en'],
      name__en: mp['name']['en'],
      name__el: mp['name']['el'],
      email: mp['email'],
      image: mp['image'],
      gender: mp['gender'],
      birth_date: mp['birth_date'],
      facebook: mp['links'].map{ |l| l['url'] }.find { |l| l.include? 'facebook' },
      twitter: mp['links'].map{ |l| l['url'] }.find { |l| l.include? 'twitter' },
      identifier__wikidata: mp['identifiers'].find { |i| i['scheme'] == 'http://www.wikidata.org/entity/' }['identifier'],
      source: mp['_sources'].find { |l| l.include? 'parliament.cy' },
    }
    if data[:source].to_s.empty?
      warn "No usable data in #{mp}"
      next
    end
    data[:id] = data[:identifier__parliament_cy] = File.basename data[:source]
    data[:identifier__openpatata] = File.basename(url, '.*')
    mp['tenures'].select { |tenure|
      tenure['end_date'].to_s.empty? || tenure['end_date'].to_s >= term[:start_date]
    }.each do |tenure|
      if tenure['parliamentary_group_id']
        pg = parl_group(tenure['parliamentary_group_id'])
        pg_name = { 'en' => pg['name']['en'], 'el' => pg['name']['el'] }
      else
        tenure['parliamentary_group_id'] = '_IND'
        pg_name = { 'en' => 'Independent', 'el' => 'Independent' }
      end
      mem = data.merge({
        term: term[:id],
        start_date: tenure['start_date'],
        end_date: tenure['end_date'],
        area: tenure['electoral_district']['en'],
        area__el: tenure['electoral_district']['el'],
        faction_id: tenure['parliamentary_group_id'],
        faction: pg_name['en'],
        faction__el: pg_name['el'],
      })
      ScraperWiki.save_sqlite([:id, :term, :faction, :start_date], mem)
    end
  end
end


term = {
  id: 2011,
  name: '2011–',
  start_date: '2011-06-02',
}
ScraperWiki.save_sqlite([:id], term, 'terms')

scrape_members(term, 'https://api.github.com/repos/openpatata/openpatata-data/contents/mps')
