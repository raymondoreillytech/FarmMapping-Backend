package com.ray.farm.mapping.service;

import jakarta.servlet.http.HttpServletRequest;
import org.springframework.stereotype.Component;
import org.springframework.util.StringUtils;

@Component
public class RequestIdentityResolver {

    public RequestIdentity resolve(HttpServletRequest request, String explicitUserKey) {
        String userKey = normalizeUserKey(explicitUserKey);
        if (userKey == null) {
            userKey = normalizeUserKey(request.getHeader("X-User-Key"));
        }
        if (userKey == null) {
            userKey = "guest";
        }

        return new RequestIdentity(userKey, resolveIpAddress(request));
    }

    private String resolveIpAddress(HttpServletRequest request) {
        String forwardedFor = request.getHeader("X-Forwarded-For");
        if (StringUtils.hasText(forwardedFor)) {
            String[] values = forwardedFor.split(",");
            for (String value : values) {
                String trimmed = value.trim();
                if (!trimmed.isEmpty()) {
                    return trimmed;
                }
            }
        }

        String remoteAddr = request.getRemoteAddr();
        return StringUtils.hasText(remoteAddr) ? remoteAddr.trim() : null;
    }

    private String normalizeUserKey(String userKey) {
        return StringUtils.hasText(userKey) ? userKey.trim() : null;
    }
}
