#!/bin/env ruby
# encoding: utf-8

require 'colorize'
require 'json'
require 'nokogiri'
require 'open-uri'
require 'pry'
require 'scraperwiki'
require 'uri'

def json_from(filename)
  JSON.parse(open(URI.join(
    'https://raw.githubusercontent.com/openpatata/openpatata-data/master/_dumps/json/',
    filename)).read, symbolize_names: true)
end

def parse_members(terms, areas, mps, parties)
  mps.each do |mp|
    next if mp[:tenures].nil?

    data = {
      id: nil,
      name: mp[:name][:en],
      name__en: mp[:name][:en],
      name__el: mp[:name][:el],
      name__tr: mp[:name][:tr],
      email: mp[:email],
      image: mp[:image],
      gender: mp[:gender],
      birth_date: mp[:birth_date],
      facebook: mp[:links].map{ |l| l[:url] }.find { |l| l.include? 'facebook' },
      twitter: mp[:links].map{ |l| l[:url] }.find { |l| l.include? 'twitter' },
      identifier__wikidata: mp[:identifiers].find { |i| i[:scheme] == 'http://www.wikidata.org/entity/' }[:identifier],
      source: mp[:_sources].find { |l| l.include? 'parliament.cy' },
    }
    if data[:source].to_s.empty?
      # warn "No usable data in #{mp}"
      next
    end
    data[:id] = data[:identifier__parliament_cy] = File.basename data[:source]
    data[:identifier__openpatata] = mp[:_id]
    mp[:tenures].each do |tenure|
      if tenure[:party_id]
        party_name = parties.find { |p| p[:_id] == tenure[:party_id] }[:name]
      else
        tenure[:party_id] = '_IND'
        party_name = { en: 'Independent', el: 'Independent', tr: 'Independent' }
      end
      area = areas.find { |a| a[:_id] == tenure[:electoral_district_id] } or raise binding.pry
      mem = data.merge({
        term: tenure[:parliamentary_period_id],
        start_date: tenure[:start_date],
        end_date: tenure[:end_date],
        area_id: tenure[:electoral_district_id],
        area: area[:name][:en],
        area__el: area[:name][:el],
        area__tr: area[:name][:tr],
        faction_id: tenure[:party_id],
        faction: party_name[:en],
        faction__el: party_name[:el],
        faction__tr: party_name[:tr],
      })
      ScraperWiki.save_sqlite([:id, :term, :faction_id], mem)
    end
  end
end

def parse_terms(terms)
  terms.each do |term|
    term = {
      id: term[:_id],
      name: "#{term[:number][:en]}th",
      start_date: term[:start_date],
      end_date: term[:end_date]
    }
    ScraperWiki.save_sqlite([:id], term, 'terms')
  end
end

areas = json_from 'electoral_districts.json'
mps = json_from 'mps.json'
parties = json_from 'parties.json'
terms = json_from 'parliamentary_periods.json'
parse_terms(terms)
parse_members(terms, areas, mps, parties)
