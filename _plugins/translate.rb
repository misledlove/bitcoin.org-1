require 'yaml'

#translate( id [,category ,lang] )
#Return translated string using translations files

#category and lang are set to current page.id and page.lang, but they can
#also be set manually to get translations for global layout and urls.
#Example: {% translate button-wallet layout %} will return the
#translated button-wallet string for the global layout file

#dynamic variables can be used as arguments
#Example: {% translate menu-{{id}} %}

#urls and anchors are automatically replaced and translated. 
#Example: #vocabulary##[vocabulary.wallet] is replaced by
#/en/vocabulary#wallet when the page is in english or
#/fr/vocabulaire#porte-monnaie when the page is in french.

module Jekyll
  class TranslateTag < Liquid::Tag

    def initialize(tag_name, id, tokens)
      super
      @id = id
    end

    def render(context)
      #load translations files
      site = context.registers[:site].config
      if !site.has_key?("loc")
        site['loc'] = {}
        site['langs'].each do |key,value|
          site['loc'][key] = YAML.load_file('_translations/'+key+'.yml')[key]
        end
      end
      #define id, category and lang
      lang = Liquid::Template.parse("{{page.lang}}").render context
      cat = Liquid::Template.parse("{{page.id}}").render context
      id=@id.split(' ')
      if !id[1].nil?
        cat = Liquid::Template.parse(id[1]).render context
      end
      if !id[2].nil?
        lang = Liquid::Template.parse(id[2]).render context
      end
      id=Liquid::Template.parse(id[0]).render context
      if lang == ''
        lang = 'en'
      end
      #get translated string
      text = ''
      if site['loc'][lang].has_key?(cat) && site['loc'][lang][cat].has_key?(id) && !site['loc'][lang][cat][id].nil?
        text = site['loc'][lang][cat][id]
      end
      #replace urls and anchors in string
      url = site['loc'][lang]['url']
      url.each do |key,value|
        if !value.nil?
          text.gsub!("#"+key+"#",'/'+lang+'/'+value)
        end
      end
      anc = site['loc'][lang]['anchor']
      anc.each do |page,anch|
        anch.each do |key,value|
          if !value.nil?
            text.gsub!("["+page+'.'+key+"]",value)
          end
        end
      end
      text
    end
  end
end

Liquid::Template.register_tag('translate', Jekyll::TranslateTag)

module Jekyll

  class TranslatePage < Page
    def initialize(site, base, id, lang, srcdir, dstdir, src, dst)
      @site = site
      @base = base
      @dir = '/'+dstdir
      @name = dst
      @id = id
      @lang = lang
      self.process(dst)
      self.read_yaml(File.join(base, srcdir), src)
      self.data['lang'] = lang
    end
  end

  class TranslatePageGenerator < Generator
    def generate(site)
      #load translations files
      locs = {}
      Dir.foreach('_translations') do |file|
        next if file == '.' or file == '..'
        lang=file.split('.')[0]
        locs[lang] = YAML.load_file("_translations/"+file)[lang]
      end
      #generate each translated page based on templates
      locs.each do |lang,value|
        Dir.foreach('_templates') do |file|
          next if file == '.' or file == '..'
          id=file.split('.')[0]
          dst=locs[lang]['url'][id]
          next if dst.nil?
          src=file
          dst=dst+'.html'
          srcdir='_templates'
          dstdir=lang
          site.pages << TranslatePage.new(site, site.source, id, lang, srcdir, dstdir, src, dst)
        end
        #generate each translated alert based on templates
        Dir.foreach('_alerts') do |file|
          next if file == '.' or file == '..' or lang != 'en'
          src=file
          dst=file
          srcdir='_alerts'
          dstdir=lang+'/alert'
          site.pages << TranslatePage.new(site, site.source, '', lang, srcdir, dstdir, src, dst)
        end
        #TODO alerts are only generated for english language,
        #but they could also be translated at some point. They would however
        #need to fallback to english when no translation is available.
        site.pages << TranslatePage.new(site, site.source, 'index', lang, '_templates', lang, 'index.html', 'index.html')
      end
    end
  end

end
