package edu.example.kotlindevelop.domain.home;

import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RequestMapping("/home")
@RestController
public class HomeController {

    public String home() {
        return "Welcome Home";
    }

}
