--
-- make_vala.lua
-- Generate a Vala project makefile.
--

	local make = premake.make

	function premake.make_vala(prj)

		-- create a shortcut to the compiler interface
		local valac = premake.gettool(prj)

		-- build a list of supported target platforms that also includes a generic build
		local platforms = premake.filterplatforms(prj.solution, valac.platforms, "Native")

		_p('# %s project makefile autogenerated by GENie', premake.action.current().shortname)

		-- set up the environment
		_p('ifndef config')
		_p('  config=%s', _MAKE.esc(premake.getconfigname(prj.solution.configurations[1], platforms[1], true)))
		_p('endif')
		_p('')

		_p('ifndef verbose')
		_p('  SILENT = @')
		_p('endif')
		_p('')

		-- identify the shell type
		_p('SHELLTYPE := msdos')
		_p('ifeq (,$(ComSpec)$(COMSPEC))')
		_p('  SHELLTYPE := posix')
		_p('endif')
		_p('ifeq (/bin,$(findstring /bin,$(SHELL)))')
		_p('  SHELLTYPE := posix')
		_p('endif')
		_p('ifeq (/bin,$(findstring /bin,$(MAKESHELL)))')
		_p('  SHELLTYPE := posix')
		_p('endif')
		_p('')

		_p('ifeq (posix,$(SHELLTYPE))')
		_p('  MKDIR = $(SILENT) mkdir -p "$(1)"')
		_p('  COPY  = $(SILENT) cp -fR "$(1)" "$(2)"')
		_p('  RM    = $(SILENT) rm -f "$(1)"')
		_p('else')
		_p('  MKDIR = $(SILENT) mkdir "$(subst /,\\\\,$(1))" 2> nul || exit 0')
		_p('  COPY  = $(SILENT) copy /Y "$(subst /,\\\\,$(1))" "$(subst /,\\\\,$(2))"')
		_p('  RM    = $(SILENT) del /F "$(subst /,\\\\,$(1))" 2> nul || exit 0')
		_p('endif')
		_p('')

		_p('VALAC = %s', valac.valac)
		_p('CC    = %s', valac.cc)
		_p('')

		-- write configuration blocks
		for _, platform in ipairs(platforms) do
			for cfg in premake.eachconfig(prj, platform) do
				premake.gmake_valac_config(prj, cfg, valac)
			end
		end

		-- list sources
		_p('SOURCES := \\')
		for _, file in ipairs(prj.files) do
			if path.issourcefile(file) then
				-- check if file is excluded.
				if not table.icontains(prj.excludes, file) then
					-- if not excluded, add it.
					_p('\t%s \\', _MAKE.esc(file))
				end
			end
		end
		_p('')

		-- main build rule(s)
		_p('.PHONY: clean prebuild prelink')
		_p('')

		-- target build rule
		_p('$(TARGET): $(SOURCES) | $(TARGETDIR)')
		_p('\t$(SILENT) $(VALAC) -o $(TARGET) --cc=$(CC) $(FLAGS) $(SOURCES)')
		_p('\t$(POSTBUILDCMDS)')
		_p('')

		-- Create destination directories. Can't use $@ for this because it loses the
		-- escaping, causing issues with spaces and parenthesis
		_p('$(TARGETDIR):')
		premake.make_mkdirrule("$(TARGETDIR)")

		-- clean target
		_p('clean:')
		if (not prj.solution.messageskip) or (not table.contains(prj.solution.messageskip, "SkipCleaningMessage")) then
			_p('\t@echo Cleaning %s', prj.name)
		end
		_p('ifeq (posix,$(SHELLTYPE))')
		_p('\t$(SILENT) rm -f  $(TARGET)')
		_p('else')
		_p('\t$(SILENT) if exist $(subst /,\\\\,$(TARGET)) del $(subst /,\\\\,$(TARGET))')
		_p('endif')
		_p('')

		-- custom build step targets
		_p('prebuild:')
		_p('\t$(PREBUILDCMDS)')
		_p('')

		_p('prelink:')
		_p('\t$(PRELINKCMDS)')
		_p('')
	end



--
-- Write a block of configuration settings.
--

	function premake.gmake_valac_config(prj, cfg, valac)

		_p('ifeq ($(config),%s)', _MAKE.esc(cfg.shortname))

		_p('  TARGETDIR  = %s', _MAKE.esc(cfg.buildtarget.directory))
		_p('  TARGET     = $(TARGETDIR)/%s', _MAKE.esc(cfg.buildtarget.name))
		_p('  DEFINES    +=%s', make.list(valac.getdefines(cfg.defines)))
		_p('  PKGS       +=%s', make.list(valac.getlinks(cfg.links)))
		_p('  FLAGS      += $(DEFINES) $(PKGS)%s', make.list(table.join(valac.getvalaflags(cfg), valac.getbuildoptions(cfg.buildoptions), valac.getbuildoptions(cfg.buildoptions_c))))

		_p('  define PREBUILDCMDS')
		if #cfg.prebuildcommands > 0 then
			_p('\t@echo Running pre-build commands')
			_p('\t%s', table.implode(cfg.prebuildcommands, "", "", "\n\t"))
		end
		_p('  endef')

		_p('  define PRELINKCMDS')
		if #cfg.prelinkcommands > 0 then
			_p('\t@echo Running pre-link commands')
			_p('\t%s', table.implode(cfg.prelinkcommands, "", "", "\n\t"))
		end
		_p('  endef')

		_p('  define POSTBUILDCMDS')
		if #cfg.postbuildcommands > 0 then
			_p('\t@echo Running post-build commands')
			_p('\t%s', table.implode(cfg.postbuildcommands, "", "", "\n\t"))
		end
		_p('  endef')

		_p('endif')
		_p('')
	end
