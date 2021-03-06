module Sitepress
  # Serves up Sitepress site pages in a rails application. This is mixed into the
  # Sitepress::SiteController, but may be included into other controllers for static
  # page behavior.
  module SitePages
    # Rails 5 requires a format to be given to the private layout method
    # to return the path to the layout.
    DEFAULT_PAGE_RAILS_FORMATS = [:html].freeze

    extend ActiveSupport::Concern

    included do
      rescue_from Sitepress::PageNotFoundError, with: :page_not_found
      helper Sitepress::Engine.helpers
      helper_method :current_page, :site
    end

    def show
      render_page current_page
    end

    protected
    def render_page(page)
      render inline: page.body,
        type: page.asset.template_extensions.last,
        layout: page.data.fetch("layout", controller_layout),
        content_type: page.mime_type.to_s
    end

    def current_page
      @_current_page ||= find_resource
    end

    def site
      Sitepress.site
    end

    def page_not_found(e)
      raise ActionController::RoutingError, e.message
    end

    private

    # Sitepress::PageNotFoundError is handled in the default Sitepress::SiteController
    # with an execption that Rails can use to display a 404 error.
    def get(path)
      resource = site.resources.get(path)
      if resource.nil?
        # TODO: Display error in context of Reources class root.
        raise Sitepress::PageNotFoundError, "No such page: #{path}"
      else
        resource
      end
    end

    # Default finder of the resource for the current controller context.###
    def find_resource
      get params[:resource_path]
    end

    # Returns the current layout for the inline Sitepress renderer. This is
    # exposed via some really convoluted private methods inside of the various
    # versions of Rails, so I try my best to hack out the path to the layout below.
    def controller_layout
      # Rails 4 and 5 expose the `_layout` via methods with different arity. Since
      # I don't want to hard code the version, I'm detecting arity and hoping that Rails 6
      # doesn't break this approach. If it does I'll probably have to get into the business
      # of version detection.
      private_layout_method = self.method(:_layout)
      layout = if private_layout_method.arity == 1 # Rails 5
        private_layout_method.call current_page_rails_formats
      else # Rails 4
        private_layout_method.call
      end

      if layout.instance_of? String # Rails 4 and 5 return a string from above.
        layout
      else # Rails 3 and older return an object that gives us a file name
        File.basename(layout.identifier).split('.').first
      end
    end

    # Rails 5 requires an extension, like `:html`, to resolve a template. This
    # method returns the intersection of the formats Rails supports from Mime::Types
    # and the current page's node formats. If nothing intersects, HTML is returned
    # as a default.
    def current_page_rails_formats
      extensions = current_page.node.formats.extensions
      supported_extensions = extensions & Mime::EXTENSION_LOOKUP.keys

      if supported_extensions.empty?
        DEFAULT_PAGE_RAILS_FORMATS
      else
        supported_extensions.map?(&:to_sym)
      end
    end
  end
end
