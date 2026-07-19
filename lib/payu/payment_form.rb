require "cgi"

module Payu
  # Return value of Client#build_payment. No network call is made to
  # produce this — it's just the signed field set and the URL to post it to.
  class PaymentForm
    attr_reader :payment_url, :fields

    def initialize(payment_url:, fields:)
      @payment_url = payment_url
      @fields = fields
    end

    # Shape expected by the bundled payu-checkout.js: new PayuCheckout(data).open()
    def to_h = { payment_url: @payment_url, fields: @fields }

    # A complete, self-contained HTML page that auto-submits to PayU on
    # load. Render this from a single GET route (e.g. GET /checkout/:id/pay)
    # and that URL is all a client needs: redirect a browser to it, or point
    # a mobile WebView at it — no client-side form building required either
    # way. Values are HTML-escaped; a <noscript> button covers JS-disabled
    # browsers.
    def to_html
      inputs = @fields.map { |name, value| hidden_input(name, value) }.join("\n      ")

      <<~HTML
        <!DOCTYPE html>
        <html>
          <head>
            <meta charset="utf-8">
            <title>Redirecting to PayU&hellip;</title>
          </head>
          <body onload="document.forms[0].submit()">
            <form method="POST" action="#{CGI.escapeHTML(@payment_url)}">
              #{inputs}
              <noscript><button type="submit">Continue to payment</button></noscript>
            </form>
          </body>
        </html>
      HTML
    end

    private

    def hidden_input(name, value)
      %(<input type="hidden" name="#{CGI.escapeHTML(name.to_s)}" value="#{CGI.escapeHTML(value.to_s)}">)
    end
  end
end
