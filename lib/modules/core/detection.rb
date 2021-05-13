# scan the url for multiple params

module MultipleParameters

    class TestAllParameters

        def check_for_multiple_parameters(site, syntax)
            if site.scan("=").count != 1
                site.sub!("=", "=" + syntax)
            end
        end
    end
end
