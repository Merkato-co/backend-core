package com.merkato.backend;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.context.ActiveProfiles;

@ActiveProfiles("test")
@ExtendWith(MockitoExtension.class)
class BackendCoreApplicationTests {

    @Test
    void contextLoads() {
        //empty because there is no code to test yet
    }

}
