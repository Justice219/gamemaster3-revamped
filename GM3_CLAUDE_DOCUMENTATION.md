# Gamemaster 3 - LYX Integration Documentation

## Overview
This document details the integration of Gamemaster 3 (GM3) with the LYX framework's updated chat command and networking systems. All GM3 systems have been updated to use the proper LYX APIs for enhanced security, performance, and maintainability.

## Key Changes Made

### 1. Chat Command System Integration

#### Previous Implementation
- GM3 used its own `PlayerSay` hook to handle commands
- Commands were processed directly without validation
- No rate limiting or cooldown system
- Basic permission checking through ranks

#### New Implementation
- All GM3 commands now use `lyx:ChatAddCommand()` for registration
- Commands are integrated with LYX's secure command framework
- Built-in features:
  - Rate limiting (configurable per command)
  - Cooldown system to prevent spam
  - Enhanced permission checking
  - Argument validation
  - Command description and usage info

#### Command Registration Example
```lua
lyx:ChatAddCommand("gm3", {
    prefix = "!",
    func = function(ply, args)
        -- Command logic here
    end,
    description = "Open the Gamemaster 3 admin menu",
    usage = "!gm3",
    permission = function(ply)
        return gm3:SecurityCheck(ply)
    end,
    cooldown = 1
})
```

### 2. Network Message Security Enhancements

#### Previous Implementation
- Basic `lyx:NetAdd()` usage without authentication
- No rate limiting on network messages
- Limited input validation
- Inconsistent error handling

#### New Implementation
- All network messages now include:
  - Authentication checks via `auth` parameter
  - Rate limiting via `rateLimit` parameter
  - Input validation for all received data
  - Proper error logging
  - Length validation for strings and tables

#### Network Message Example
```lua
lyx:NetAdd("gm3:tool:run", {
    func = function(ply, len)
        -- Validate and process message
    end,
    auth = function(ply)
        return gm3:SecurityCheck(ply)
    end,
    rateLimit = 10  -- Max 10 messages per second
})
```

### 3. Security Improvements

#### Input Validation
- All string inputs are now length-checked (max 32-64 characters)
- Table sizes are validated before processing
- Command and rank names are sanitized
- Console commands are whitelisted on client-side

#### Permission System
- GM3 rank system integrated with LYX permissions
- Superadmin-only operations properly restricted
- Security checks on all sensitive operations
- Prevention of superadmin rank removal

#### Rate Limiting
- All network messages have appropriate rate limits:
  - Security checks: 5/second
  - Tool execution: 10/second
  - Rank operations: 5/second
  - Command operations: 5-10/second
  - Sync requests: 3/second

### 4. Dynamic Command Management

#### How It Works
1. Commands created through GM3 menu are stored in `gm3.commands`
2. Each command is registered with LYX using `lyx:ChatAddCommand()`
3. Commands include rank-based permissions from GM3
4. Commands are saved/loaded from JSON storage
5. On server start, saved commands are re-registered with LYX

#### Command Lifecycle
```
Create Command → Store in GM3 → Register with LYX → Save to JSON
Load from JSON → Re-register with LYX → Available for use
```

### 5. Client-Side Updates

#### Enhanced Network Handlers
- All client-side `lyx:NetAdd()` handlers updated
- Proper parameter handling (using `len` parameter)
- Input validation on received data
- Console command whitelist for security

#### Improved Sync System
- Better validation of sync data
- Detailed logging of sync operations
- Proper null checks on UI elements

## File Changes Summary

### Server-Side Files
- `sv_gm3_chat.lua`: Complete rewrite using LYX chat system
- `sv_gm3_net.lua`: Enhanced with authentication and rate limiting

### Client-Side Files
- `cl_gm3_chat.lua`: Updated command display formatting
- `cl_gm3_net.lua`: Enhanced security and validation

## Usage Guide

### Creating Custom Commands
1. Use GM3 menu to create command
2. Command automatically registers with LYX
3. Set rank permissions through GM3
4. Command persists across server restarts

### Command Syntax
- All commands use configured prefix (default: "!")
- Arguments are space-separated
- Commands have built-in cooldowns
- Rate limiting prevents spam

### Admin Operations
- All admin operations require GM3 security check
- Superadmin operations have additional restrictions
- Network messages are authenticated and rate-limited

## Migration Notes

### For Server Owners
- Existing GM3 commands will be automatically migrated
- Commands load from `gm3_commands.txt` and register with LYX
- No manual intervention required

### For Developers
- Use `lyx:ChatAddCommand()` for new commands
- Include proper authentication in network messages
- Always validate input data
- Use appropriate rate limits

## Security Best Practices

1. **Never trust client input** - Always validate
2. **Use authentication** - Add `auth` parameter to sensitive messages
3. **Rate limit everything** - Prevent spam and DoS
4. **Validate lengths** - Check string and table sizes
5. **Log security events** - Track unauthorized attempts
6. **Whitelist commands** - Only allow safe console commands

## Troubleshooting

### Commands Not Working
- Check if command is registered: Look for registration log
- Verify permissions: Ensure player has required rank
- Check cooldown: Wait for cooldown period
- Review chat prefix: Ensure using correct prefix

### Network Messages Failing
- Check rate limits: May be hitting rate limit
- Verify authentication: Ensure proper permissions
- Review logs: Check for validation errors
- Validate input: Ensure data meets requirements

## Future Improvements

### Planned Features
- Command aliases support
- Advanced argument parsing
- Command categories
- Permission groups beyond ranks
- Command usage statistics

### Performance Optimizations
- Batch command registration
- Cached permission checks
- Optimized sync operations

## Support

For issues or questions about the GM3-LYX integration:
1. Check this documentation
2. Review error logs
3. Verify LYX framework is updated
4. Contact support with specific error messages

---

*Last Updated: Current Session*
*Version: GM3-LYX Integration 1.0*